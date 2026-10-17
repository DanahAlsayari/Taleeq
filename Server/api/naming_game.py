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
