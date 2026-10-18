import base64
import json
import os
import re

from dotenv import load_dotenv
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from openai import OpenAI
from sqlalchemy import text
from sqlalchemy.orm import Session

from application_layer.authentication_managment import auth
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.user import User
from data_and_integration_layer.ai_integration.openai_audio import (
    OpenAIAudioAnalyzer,
    UnusableSpeechError,
)

load_dotenv()
router = APIRouter(prefix="/games/naming-challenge", tags=["Naming Challenge"])
SUPPORTED_FORMATS = {"wav", "mp3", "m4a", "webm"}
MAX_AUDIO_SIZE = 15 * 1024 * 1024


def ensure_score_table(db: Session) -> None:
    db.execute(text("""
        CREATE TABLE IF NOT EXISTS naming_challenge_scores (
            user_id TEXT NOT NULL,
            prompt_id INTEGER NOT NULL,
            last_score INTEGER NOT NULL DEFAULT 0,
            best_score INTEGER NOT NULL DEFAULT 0,
            attempt_count INTEGER NOT NULL DEFAULT 0,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (user_id, prompt_id)
        )
    """))
    db.commit()


def ensure_attempt_table(db: Session) -> None:
    """Create the individual-attempt history table if it does not exist."""
    db.execute(text("""
        CREATE TABLE IF NOT EXISTS naming_challenge_attempts (
            id BIGSERIAL PRIMARY KEY,
            user_id TEXT NOT NULL,
            prompt_id INTEGER NOT NULL,
            valid_items JSONB NOT NULL DEFAULT '[]'::jsonb,
            valid_count INTEGER NOT NULL DEFAULT 0,
            speech_analysis JSONB,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """))
    db.commit()


def parse_json_response(content: str) -> dict:
    content = content.strip()
    content = re.sub(r"^```(?:json)?\\s*", "", content)
    content = re.sub(r"\\s*```$", "", content)
    try:
        result = json.loads(content)
    except json.JSONDecodeError:
        start, end = content.find("{"), content.rfind("}")
        if start == -1 or end == -1:
            raise ValueError("Invalid JSON response from AI.")
        result = json.loads(content[start:end + 1])
    if not isinstance(result, dict):
        raise ValueError("AI response must be a JSON object.")
    return result


def evaluate_answers(audio_bytes: bytes, audio_format: str, prompt_ar: str,
                     category: str, challenge_type: str) -> list[str]:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY is not configured.")
    client = OpenAI(api_key=api_key)
    encoded_audio = base64.b64encode(audio_bytes).decode("utf-8")
    instructions = f"""
Listen to the attached audio recording for the Taleeq Naming Challenge.
Question displayed to the user: {prompt_ar}
Category identifier: {category}
Challenge type: {challenge_type}
Identify valid answers the speaker actually said, in order.
- Do not invent or guess spoken answers.
- Accept recognizable Arabic or English answers when appropriate.
- For category questions, answers must belong to the category.
- For letter questions, answers must begin with the requested letter.
- Count each distinct valid answer only once.
- Ignore unrelated, unclear, or invalid answers.
- Do not assess stuttering in this request.
Return ONLY JSON: {{"valid_items": ["answer 1", "answer 2"]}}
"""
    response = client.chat.completions.create(
        model="gpt-audio-1.5",
        messages=[{"role": "user", "content": [
            {"type": "text", "text": instructions},
            {"type": "input_audio", "input_audio": {
                "data": encoded_audio, "format": audio_format,
            }},
        ]}],
    )
    content = response.choices[0].message.content
    if not content:
        raise ValueError("Empty response from AI.")
    items = parse_json_response(content).get("valid_items")
    if not isinstance(items, list):
        raise ValueError("AI response is missing valid_items.")
    valid_items, seen = [], set()
    for item in items:
        if isinstance(item, str):
            item = item.strip()
            normalized = item.casefold()
            if item and normalized not in seen:
                seen.add(normalized)
                valid_items.append(item)
    return valid_items
@router.get("/prompts/random")
def get_random_prompt(
    difficulty: str,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    if difficulty not in {"easy", "medium", "hard"}:
        raise HTTPException(
            status_code=422,
            detail="Invalid difficulty.",
        )

    prompt = db.execute(
        text("""
            SELECT
                id,
                prompt_ar,
                prompt_en,
                category,
                challenge_type,
                duration_seconds,
                difficulty
            FROM naming_challenge_prompts
            WHERE is_active = TRUE
              AND difficulty = :difficulty
            ORDER BY RANDOM()
            LIMIT 1
        """),
        {"difficulty": difficulty},
    ).mappings().first()

    if prompt is None:
        raise HTTPException(
            status_code=404,
            detail="No active questions found for this difficulty.",
        )

    return dict(prompt)

@router.post("/analyze")
async def analyze_naming_challenge(
    prompt_id: int = Form(...),
    file: UploadFile = File(...),
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    prompt = db.execute(text("""
        SELECT id, prompt_ar, category, challenge_type, duration_seconds
        FROM naming_challenge_prompts
        WHERE id = :prompt_id AND is_active = TRUE
    """), {"prompt_id": prompt_id}).mappings().first()
    if prompt is None:
        raise HTTPException(status_code=404, detail="Challenge question not found.")

    filename = file.filename or ""
    if "." not in filename:
        raise HTTPException(status_code=400, detail="Audio file format is missing.")
    audio_format = filename.rsplit(".", 1)[-1].lower()
    if audio_format not in SUPPORTED_FORMATS:
        raise HTTPException(status_code=400, detail="Unsupported audio format.")

    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="التسجيل الصوتي فارغ.")
    if len(audio_bytes) > MAX_AUDIO_SIZE:
        raise HTTPException(status_code=413, detail="Audio file exceeds 15 MB.")

    try:
        speech_analysis = OpenAIAudioAnalyzer().analyze_audio(audio_bytes, audio_format)
        valid_items = evaluate_answers(
            audio_bytes, audio_format, prompt["prompt_ar"],
            prompt["category"], prompt["challenge_type"],
        )
    except UnusableSpeechError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    except Exception as error:
        print(f"Naming Challenge analysis failed: {error}")
        raise HTTPException(status_code=502, detail="تعذر تحليل التسجيل حاليًا. حاول مرة أخرى.") from error

    valid_count = len(valid_items)
    user_id = str(current_user.id)

    try:
        ensure_score_table(db)
        old = db.execute(text("""
            SELECT last_score, best_score
            FROM naming_challenge_scores
            WHERE user_id = :user_id AND prompt_id = :prompt_id
        """), {"user_id": user_id, "prompt_id": prompt["id"]}).mappings().first()

        previous_score = int(old["last_score"]) if old else 0
        previous_best = int(old["best_score"]) if old else 0
        best_score = max(previous_best, valid_count)
        new_record = valid_count > previous_best

        ensure_attempt_table(db)
        db.execute(text("""
            INSERT INTO naming_challenge_scores
                (user_id, prompt_id, last_score, best_score, attempt_count, updated_at)
            VALUES (:user_id, :prompt_id, :last_score, :best_score, 1, CURRENT_TIMESTAMP)
            ON CONFLICT (user_id, prompt_id) DO UPDATE SET
                last_score = EXCLUDED.last_score,
                best_score = GREATEST(naming_challenge_scores.best_score, EXCLUDED.best_score),
                attempt_count = naming_challenge_scores.attempt_count + 1,
                updated_at = CURRENT_TIMESTAMP
        """), {
            "user_id": user_id, "prompt_id": prompt["id"],
            "last_score": valid_count, "best_score": best_score,
        })

        # Persist every successful analysis as its own attempt, not just an aggregate score.
        db.execute(text("""
            INSERT INTO naming_challenge_attempts
                (user_id, prompt_id, valid_items, valid_count, speech_analysis, created_at)
            VALUES (
                :user_id, :prompt_id, CAST(:valid_items AS JSONB),
                :valid_count, CAST(:speech_analysis AS JSONB), CURRENT_TIMESTAMP
            )
        """), {
            "user_id": user_id,
            "prompt_id": prompt["id"],
            "valid_items": json.dumps(valid_items, ensure_ascii=False),
            "valid_count": valid_count,
            "speech_analysis": json.dumps(speech_analysis.model_dump(), ensure_ascii=False, default=str),
        })
        db.commit()
        saved = db.execute(text("""
            SELECT attempt_count FROM naming_challenge_scores
            WHERE user_id = :user_id AND prompt_id = :prompt_id
        """), {"user_id": user_id, "prompt_id": prompt["id"]}).mappings().first()
    except Exception as error:
        db.rollback()
        print(f"Naming Challenge score saving failed: {error}")
        raise HTTPException(status_code=500, detail="تعذر حفظ النتيجة.") from error

    return {
        "game": "Naming Challenge",
        "prompt_id": prompt["id"],
        "valid_items": valid_items,
        "valid_count": valid_count,
        "previous_score": previous_score,
        "previous_best_score": previous_best,
        "best_score": best_score,
        "last_score": valid_count,
        "attempt_count": int(saved["attempt_count"]) if saved else 1,
        "new_record": new_record,
        "duration_seconds": prompt["duration_seconds"],
        "speech_analysis": speech_analysis.model_dump(),
    }

@router.get("/attempts")
def get_naming_challenge_attempts(
    limit: int = 50,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    """Return real individual attempts for the signed-in user, newest first."""
    ensure_attempt_table(db)
    safe_limit = max(1, min(limit, 100))
    rows = db.execute(text("""
        SELECT
            a.id,
            a.prompt_id,
            p.prompt_ar AS prompt,
            p.difficulty,
            p.category,
            p.challenge_type,
            a.valid_items,
            a.valid_count,
            a.speech_analysis,
            a.created_at
        FROM naming_challenge_attempts AS a
        LEFT JOIN naming_challenge_prompts AS p ON p.id = a.prompt_id
        WHERE a.user_id = :user_id
        ORDER BY a.created_at DESC, a.id DESC
        LIMIT :limit
    """), {"user_id": str(current_user.id), "limit": safe_limit}).mappings().all()

    return {
        "total_attempts": len(rows),
        "attempts": [
            {
                "id": row["id"],
                "attempt_id": row["id"],
                "prompt_id": row["prompt_id"],
                "prompt": row["prompt"],
                "difficulty": row["difficulty"],
                "category": row["category"],
                "challenge_type": row["challenge_type"],
                "valid_items": row["valid_items"] or [],
                "valid_count": row["valid_count"],
                "speech_analysis": row["speech_analysis"],
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            }
            for row in rows
        ],
    }


@router.get("/scores")
def get_naming_challenge_scores(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    ensure_score_table(db)
    ensure_attempt_table(db)

    rows = db.execute(text("""
        SELECT
            s.prompt_id,
            p.prompt_ar,
            p.difficulty,
            s.last_score,
            s.best_score,
            s.attempt_count,
            s.updated_at
        FROM naming_challenge_scores AS s
        LEFT JOIN naming_challenge_prompts AS p ON p.id = s.prompt_id
        WHERE s.user_id = :user_id
        ORDER BY s.updated_at DESC
    """), {"user_id": str(current_user.id)}).mappings().all()

    attempts_rows = db.execute(text("""
        SELECT
            a.id,
            a.prompt_id,
            p.prompt_ar AS prompt,
            p.difficulty,
            a.valid_items,
            a.valid_count,
            a.speech_analysis,
            a.created_at
        FROM naming_challenge_attempts AS a
        LEFT JOIN naming_challenge_prompts AS p ON p.id = a.prompt_id
        WHERE a.user_id = :user_id
        ORDER BY a.created_at DESC, a.id DESC
        LIMIT 50
    """), {"user_id": str(current_user.id)}).mappings().all()

    return {
        "total_questions_played": len(rows),
        "total_attempts": sum(int(row["attempt_count"]) for row in rows),
        "scores": [
            {
                "prompt_id": row["prompt_id"],
                "prompt": row["prompt_ar"],
                "difficulty": row["difficulty"],
                "last_score": row["last_score"],
                "best_score": row["best_score"],
                "attempt_count": row["attempt_count"],
                "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
            }
            for row in rows
        ],
        "attempts": [
            {
                "id": row["id"],
                "attempt_id": row["id"],
                "prompt_id": row["prompt_id"],
                "prompt": row["prompt"],
                "difficulty": row["difficulty"],
                "valid_items": row["valid_items"] or [],
                "valid_count": row["valid_count"],
                "speech_analysis": row["speech_analysis"],
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            }
            for row in attempts_rows
        ],
    }
