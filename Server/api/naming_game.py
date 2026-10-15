
import base64
import json
import os
import re

from dotenv import load_dotenv
from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    UploadFile,
)
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

router = APIRouter(
    prefix="/games/naming-challenge",
    tags=["Naming Challenge"],
)

SUPPORTED_FORMATS = {"wav", "mp3", "m4a", "webm"}
MAX_AUDIO_SIZE = 15 * 1024 * 1024


def parse_json_response(content: str) -> dict:
    content = content.strip()
    content = re.sub(r"^```(?:json)?\s*", "", content)
    content = re.sub(r"\s*```$", "", content)

    try:
        result = json.loads(content)
    except json.JSONDecodeError:
        start = content.find("{")
        end = content.rfind("}")

        if start == -1 or end == -1:
            raise ValueError("Invalid JSON response from AI.")

        result = json.loads(content[start:end + 1])

    if not isinstance(result, dict):
        raise ValueError("AI response must be a JSON object.")

    return result


def evaluate_answers(
    audio_bytes: bytes,
    audio_format: str,
    prompt_ar: str,
    category: str,
    challenge_type: str,
) -> list[str]:
    api_key = os.getenv("OPENAI_API_KEY")

    if not api_key:
        raise ValueError("OPENAI_API_KEY is not configured.")

    client = OpenAI(api_key=api_key)
    encoded_audio = base64.b64encode(audio_bytes).decode("utf-8")

    prompt = f"""
Listen to the attached audio recording for the Taleeq Naming Challenge.

Question displayed to the user:
{prompt_ar}

Category identifier: {category}
Challenge type: {challenge_type}

Identify the valid answers that the speaker actually said, in order.

Rules:
- Listen to the actual audio. Do not invent or guess spoken answers.
- Accept recognizable Arabic or English answers when appropriate.
- For category questions, an answer must belong to the requested category.
- For letter questions, each answer must begin with the requested letter.
- Count each distinct valid answer only once.
- Do not count repetitions of the same answer more than once.
- Ignore unrelated, unclear, or invalid answers.
- Do not assess stuttering in this request.
- Return ONLY valid JSON in this format:
{{"valid_items": ["answer 1", "answer 2"]}}
"""

    response = client.chat.completions.create(
        model="gpt-audio-1.5",
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "input_audio",
                        "input_audio": {
                            "data": encoded_audio,
                            "format": audio_format,
                        },
                    },
                ],
            }
        ],
    )

    content = response.choices[0].message.content

    if not content:
        raise ValueError("Empty response from AI.")

    result = parse_json_response(content)
    items = result.get("valid_items")

    if not isinstance(items, list):
        raise ValueError("AI response is missing valid_items.")

    valid_items = []
    seen = set()

    for item in items:
        if not isinstance(item, str):
            continue

        item = item.strip()
        normalized = item.casefold()

        if item and normalized not in seen:
            seen.add(normalized)
            valid_items.append(item)

    return valid_items


@router.get("/prompts/random")
def get_random_prompt(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    query = text("""
        SELECT
            id,
            prompt_ar,
            prompt_en,
            category,
            challenge_type,
            duration_seconds
        FROM naming_challenge_prompts
        WHERE is_active = TRUE
        ORDER BY RANDOM()
        LIMIT 1
    """)

    prompt = db.execute(query).mappings().first()

    if prompt is None:
        raise HTTPException(
            status_code=404,
            detail="No active Naming Challenge questions found.",
        )

    return dict(prompt)


@router.post("/analyze")
async def analyze_naming_challenge(
    prompt_id: int = Form(...),
    target_count: int = Form(...),
    file: UploadFile = File(...),
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    if not 1 <= target_count <= 60:
        raise HTTPException(
            status_code=400,
            detail="target_count must be between 1 and 60.",
        )

    prompt = db.execute(
        text("""
            SELECT
                id,
                prompt_ar,
                category,
                challenge_type,
                duration_seconds
            FROM naming_challenge_prompts
            WHERE id = :prompt_id
              AND is_active = TRUE
        """),
        {"prompt_id": prompt_id},
    ).mappings().first()

    if prompt is None:
        raise HTTPException(
            status_code=404,
            detail="Challenge question not found.",
        )

    filename = file.filename or ""

    if "." not in filename:
        raise HTTPException(
            status_code=400,
            detail="Audio file format is missing.",
        )

    audio_format = filename.rsplit(".", 1)[-1].lower()

    if audio_format not in SUPPORTED_FORMATS:
        raise HTTPException(
            status_code=400,
            detail="Unsupported audio format.",
        )

    audio_bytes = await file.read()

    if not audio_bytes:
        raise HTTPException(
            status_code=400,
            detail="التسجيل الصوتي فارغ.",
        )

    if len(audio_bytes) > MAX_AUDIO_SIZE:
        raise HTTPException(
            status_code=413,
            detail="Audio file exceeds 15 MB.",
        )

    try:
        # Existing Taleeq stuttering analysis.
        analyzer = OpenAIAudioAnalyzer()
        speech_analysis = analyzer.analyze_audio(
            audio_bytes,
            audio_format,
        )

        # Evaluate the answer to the database question.
        valid_items = evaluate_answers(
            audio_bytes=audio_bytes,
            audio_format=audio_format,
            prompt_ar=prompt["prompt_ar"],
            category=prompt["category"],
            challenge_type=prompt["challenge_type"],
        )

    except UnusableSpeechError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

    except ValueError as error:
        raise HTTPException(
            status_code=422,
            detail=str(error),
        ) from error

    except Exception as error:
        print(f"Naming Challenge analysis failed: {error}")

        raise HTTPException(
            status_code=502,
            detail="تعذر تحليل التسجيل حاليًا. حاولي مرة أخرى.",
        ) from error

    valid_count = len(valid_items)

    return {
        "game": "Naming Challenge",
        "prompt_id": prompt["id"],
        "target_count": target_count,
        "valid_items": valid_items,
        "valid_count": valid_count,
        "success": valid_count >= target_count,
        "result_message": (
            "نجحت!" if valid_count >= target_count
            else "حاولي مرة أخرى"
        ),
        "duration_seconds": prompt["duration_seconds"],
        "speech_analysis": speech_analysis.model_dump(),
    }
