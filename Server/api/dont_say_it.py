
import base64
import json
import os
import re
from io import BytesIO

from dotenv import load_dotenv
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from openai import OpenAI
from sqlalchemy import text
from sqlalchemy.orm import Session
from openai import APIStatusError
from application_layer.authentication_managment import auth
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.ai_integration.openai_audio import (
    OpenAIAudioAnalyzer,
    UnusableSpeechError,
)


load_dotenv()

router = APIRouter(
    prefix="/games/dont-say-it",
    tags=["Don't Say It"],
)

SUPPORTED_FORMATS = {"wav", "mp3", "m4a", "webm"}
MAX_AUDIO_SIZE = 15 * 1024 * 1024

PREDICTION_MODEL = "gpt-4o-mini"
VALIDATION_MODEL = "gpt-audio-1.5"


# ---------------------------------------------------------
# Prompt 1: Predict the word from the transcript only.
# The original target and forbidden words are NOT provided.
# ---------------------------------------------------------

PREDICT_WORD_PROMPT = """
أنت تلعب دور المقيّم في لعبة «لا تقولها» (Don't Say It).

ستستقبل وصفًا نصيًا كتبه نظام آخر اعتمادًا على كلام المستخدم
في التسجيل الصوتي. مهمتك هي استنتاج الكلمة أو المفهوم الذي
يحاول المستخدم وصفه.

التعليمات:
- اقرأ وصف المستخدم بعناية، واستنتج الكلمة الأكثر احتمالًا
  التي يشير إليها.
- اعتمد على معنى الوصف وسياقه، وليس على تطابق الكلمات حرفيًا.
- إذا كان الوصف يحتمل عدة كلمات، اختر الكلمة الأكثر احتمالًا
  بناءً على المعلومات المتاحة.
- لا تفترض أن الوصف صحيح أو كافٍ لمجرد أن المستخدم يتحدث بثقة.
- إذا كان الوصف غير كافٍ لتحديد كلمة معقولة، أعد قيمة null.
- لا تتلقَّ أي معلومات عن الكلمة الأصلية أو الكلمات الممنوعة،
  ولا تحاول افتراضها مسبقًا.

أعد النتيجة بصيغة JSON فقط، وفق البنية التالية:
{
  "predicted_word": "الكلمة التي تتوقعها",
  "confidence": 0.0,
  "reasoning_ar": "سبب مختصر يوضح كيف قادك الوصف إلى هذا التوقع"
}

اجعل confidence قيمة بين 0 و1، تعبّر عن مدى ثقتك في توقعك.
إذا لم تتمكن من استنتاج كلمة معقولة، اجعل predicted_word
تساوي null وconfidence تساوي 0.
"""


# ---------------------------------------------------------
# Prompt 2: Validate the original recording against the rules.
# The model receives the recording, target, forbidden words,
# and the prediction made by Prompt 1.
# ---------------------------------------------------------

VALIDATE_GAME_PROMPT = """
أنت مسؤول عن التحقق من نتيجة لعبة «لا تقولها» (Don't Say It).

ستستقبل المعلومات التالية:
- الكلمة الأصلية التي كان على المستخدم وصفها.
- الكلمة التي توقعها المودل الأول من وصف المستخدم.
- قائمة الكلمات الممنوعة في التحدي.
- التسجيل الصوتي الأصلي للمستخدم.

مهمتك هي تحديد ما إذا كان المستخدم قد نجح في إيصال معنى
الكلمة الأصلية دون مخالفة قواعد اللعبة.

قواعد التقييم:

1. قارن الكلمة المتوقعة بالكلمة الأصلية من حيث المعنى،
   وليس التطابق الحرفي فقط.
2. اقبل المرادفات أو التعبيرات المختلفة إذا كانت تشير بوضوح
   إلى المفهوم نفسه.
3. إذا كانت الكلمة المتوقعة تدل على مفهوم مختلف عن الكلمة
   الأصلية، فاعتبر أن المستخدم لم ينجح في إيصال المعنى.
4. افحص التسجيل الصوتي لتحديد ما إذا كان المستخدم قد نطق
   الكلمة الأصلية نفسها. واعتبره فشل في حال نطقها
5. افحص التسجيل لتحديد ما إذا كان المستخدم قد نطق أي كلمة
   من الكلمات الممنوعة. واعتبره فشل في حال نطق واحده او اكثر من الكلمات الممنوعةو
6. لا تعتبر التوقع الصحيح وحده دليلًا على أن المستخدم التزم
   بقواعد اللعبة.
7. لا تغيّر توقع المودل الأول ولا تستنتج توقعًا بديلًا؛
   استخدم التوقع المُعطى لك.
8. إذا تعذّر التحقق من إحدى المخالفات بشكل موثوق، وضّح ذلك
   ولا تدّعِ أن التحقق اكتمل.

أعد النتيجة بصيغة JSON فقط:
{
  "meaning_matched": false,
  "target_word_spoken": false,
  "forbidden_word_spoken": false,
  "matched_forbidden_words": [],
  "transcript": "",
  "passed": false,
  "reasoning_ar": "تفسير مختصر للنتيجة"
}

يكون passed صحيحًا فقط إذا:
- كان المعنى الذي توقعه المودل الأول مطابقًا لمعنى الكلمة الأصلية.
- لم ينطق المستخدم الكلمة الأصلية نفسها.
- لم ينطق المستخدم أي كلمة ممنوعة.
- توفرت معلومات موثوقة للتحقق من جميع شروط الفوز.

إذا لم تتوفر معلومات كافية للتحقق من المخالفات، فلا تعتبر
المستخدم فائزًا.

"""


# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------

def get_openai_client() -> OpenAI:
    api_key = os.getenv("OPENAI_API_KEY")

    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="OPENAI_API_KEY is not configured.",
        )

    return OpenAI(api_key=api_key)


def parse_json_response(content: str) -> dict:
    """Parse a JSON response, including JSON wrapped in code fences."""
    if not content:
        raise ValueError("The model returned an empty response.")

    cleaned = re.sub(
        r"^\s*```(?:json)?\s*",
        "",
        content,
        flags=re.IGNORECASE,
    )
    cleaned = re.sub(r"\s*```\s*$", "", cleaned)

    start = cleaned.find("{")
    end = cleaned.rfind("}")

    if start == -1 or end == -1 or end < start:
        raise ValueError("The model response does not contain JSON.")

    return json.loads(cleaned[start : end + 1])


def normalize_word_list(value) -> list[str]:
    """Convert a JSONB/list value to a list of non-empty strings."""
    if value is None:
        return []

    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            return [value] if value.strip() else []

    if not isinstance(value, list):
        return []

    return [
        str(word).strip()
        for word in value
        if word is not None and str(word).strip()
    ]


def normalize_audio_format(filename: str | None) -> str:
    if not filename or "." not in filename:
        raise HTTPException(
            status_code=400,
            detail="The uploaded audio file must have a valid extension.",
        )

    audio_format = filename.rsplit(".", 1)[-1].lower()

    if audio_format not in SUPPORTED_FORMATS:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Unsupported audio format: {audio_format}. "
                f"Supported formats: {', '.join(sorted(SUPPORTED_FORMATS))}"
            ),
        )

    return audio_format


# ---------------------------------------------------------
# Step 1: Transcribe the audio to text.
# This transcription is used as the input for the prediction
# model. No target or forbidden words are sent here.
# ---------------------------------------------------------

def transcribe_audio(audio_bytes: bytes, filename: str) -> str:
    client = get_openai_client()

    try:
        transcription = client.audio.transcriptions.create(
            model="whisper-1",
            file=(filename, BytesIO(audio_bytes)),
            language="ar",
        )

        transcript = (transcription.text or "").strip()

        if not transcript:
            raise HTTPException(
                status_code=422,
                detail="No speech could be transcribed from the audio.",
            )

        return transcript

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Audio transcription failed: {str(exc)}",
        ) from exc


# ---------------------------------------------------------
# Step 2: Ask the first model to predict the target concept.
# Only the transcript and prediction prompt are provided.
# ---------------------------------------------------------

def predict_target_word(transcript: str) -> dict:
    client = get_openai_client()

    try:
        response = client.chat.completions.create(
            model=PREDICTION_MODEL,
            messages=[
                {
                    "role": "system",
                    "content": PREDICT_WORD_PROMPT,
                },
                {
                    "role": "user",
                    "content": (
                        "هذا هو النص الناتج عن التسجيل الصوتي. "
                        "استنتج الكلمة التي يحاول المستخدم وصفها:\n\n"
                        f"{transcript}"
                    ),
                },
            ],
            response_format={"type": "json_object"},
            temperature=0,
        )

        result = parse_json_response(
            response.choices[0].message.content or ""
        )

        predicted_word = result.get("predicted_word")
        confidence = result.get("confidence", 0)

        if predicted_word is not None:
            predicted_word = str(predicted_word).strip() or None

        try:
            confidence = float(confidence)
        except (TypeError, ValueError):
            confidence = 0.0

        confidence = max(0.0, min(1.0, confidence))

        return {
            "predicted_word": predicted_word,
            "confidence": confidence,
            "reasoning_ar": str(result.get("reasoning_ar", "")),
        }

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Target prediction failed: {str(exc)}",
        ) from exc


# ---------------------------------------------------------
# Step 3: Send the original audio to the second model.
# It checks the spoken target/forbidden words and compares
# the frozen prediction with the original target.
# ---------------------------------------------------------

def validate_game(
    audio_bytes: bytes,
    audio_format: str,
    target_word_ar: str,
    target_word_en: str | None,
    accepted_target_answers: list[str],
    forbidden_words: list[str],
    prediction_result: dict,
) -> dict:
    client = get_openai_client()

    if not prediction_result.get("predicted_word"):
        # There is no meaningful prediction to compare.
        # Still send the recording for rule checking.
        predicted_word = None
    else:
        predicted_word = prediction_result["predicted_word"]

    game_context = {
        "target_word_ar": target_word_ar,
        "target_word_en": target_word_en,
        "accepted_target_answers": accepted_target_answers,
        "forbidden_words": forbidden_words,
        "predicted_word": predicted_word,
        "prediction_confidence": prediction_result.get("confidence", 0),
        "prediction_reasoning_ar": prediction_result.get(
            "reasoning_ar", ""
        ),
    }

    audio_base64 = base64.b64encode(audio_bytes).decode("utf-8")

    try:
        response = client.chat.completions.create(
            model=VALIDATION_MODEL,
            modalities=["text"],
            messages=[
                {
                    "role": "system",
                    "content": VALIDATE_GAME_PROMPT,
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": (
                                "قيّم التسجيل وفق قواعد اللعبة. "
                                "هذه بيانات التحدي وتوقع المودل الأول:\n"
                                f"{json.dumps(game_context, ensure_ascii=False)}\n\n"
                                "افحص التسجيل الصوتي المرفق نفسه. "
                                "لا تغيّر predicted_word."
                            ),
                        },
                        {
                            "type": "input_audio",
                            "input_audio": {
                                "data": audio_base64,
                                "format": audio_format,
                            },
                        },
                    ],
                },
            ],
            temperature=0,
        )

        result = parse_json_response(
            response.choices[0].message.content or ""
        )

        meaning_matched = bool(result.get("meaning_matched", False))
        target_word_spoken = bool(
            result.get("target_word_spoken", False)
        )
        forbidden_word_spoken = bool(
            result.get("forbidden_word_spoken", False)
        )

        matched_forbidden_words = normalize_word_list(
            result.get("matched_forbidden_words", [])
        )

        # Do not trust the model's "passed" field alone.
        # Recalculate it using all required conditions.
        passed = (
            predicted_word is not None
            and meaning_matched
            and not target_word_spoken
            and not forbidden_word_spoken
        )

        return {
            "predicted_word": predicted_word,
            "meaning_matched": meaning_matched,
            "target_word_spoken": target_word_spoken,
            "forbidden_word_spoken": forbidden_word_spoken,
            "matched_forbidden_words": matched_forbidden_words,
            "transcript": str(result.get("transcript", "")),
            "passed": passed,
            "reasoning_ar": str(result.get("reasoning_ar", "")),
        }
    except APIStatusError as error:
        print("OpenAI status:", error.status_code)
        print("OpenAI error:", str(error))
        print("OpenAI response body:", error.response.text)
        raise
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Game validation failed: {str(exc)}",
        ) from exc


# ---------------------------------------------------------
# GET: Fetch a random active challenge.
# Existing endpoint behavior is preserved.
# ---------------------------------------------------------
@router.get("/challenges/random")
def get_random_challenge(
    difficulty: str,
    db: Session = Depends(get_db),
):
    allowed_difficulties = {"easy", "medium", "hard"}

    if difficulty not in allowed_difficulties:
        raise HTTPException(
            status_code=422,
            detail="Invalid difficulty. Use easy, medium, or hard.",
        )

    query = text("""
        SELECT
            id,
            target_word_ar,
            target_word_en,
            forbidden_word_ar,
            forbidden_word_en,
            forbidden_words,
            accepted_target_answers,
            difficulty,
            duration_seconds
        FROM dont_say_it_challenges
        WHERE is_active = TRUE
          AND difficulty = :difficulty
        ORDER BY RANDOM()
        LIMIT 1
    """)

    challenge = db.execute(
        query,
        {"difficulty": difficulty},
    ).mappings().first()

    if not challenge:
        raise HTTPException(
            status_code=404,
            detail="No active Don't Say It challenges found for this difficulty.",
        )

    forbidden_words = normalize_word_list(
        challenge.get("forbidden_words")
    )

    if not forbidden_words:
        forbidden_words = [
            str(word).strip()
            for word in (
                challenge.get("forbidden_word_ar"),
                challenge.get("forbidden_word_en"),
            )
            if word and str(word).strip()
        ]

    return {
        "id": challenge["id"],
        "target_word_ar": challenge["target_word_ar"],
        "target_word_en": challenge["target_word_en"],
        "forbidden_words": forbidden_words,
        "difficulty": challenge["difficulty"],
        "duration_seconds": challenge["duration_seconds"],
    }
# ---------------------------------------------------------
# POST: Analyze the attempt, evaluate the game, and save it.
# ---------------------------------------------------------

@router.post("/analyze")
async def analyze_dont_say_it(
    challenge_id: int = Form(...),
    file: UploadFile = File(...),
    current_user=Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    # 1. Read and validate the uploaded audio.
    audio_bytes = await file.read()

    if not audio_bytes:
        raise HTTPException(
            status_code=400,
            detail="The uploaded audio file is empty.",
        )

    if len(audio_bytes) > MAX_AUDIO_SIZE:
        raise HTTPException(
            status_code=413,
            detail="The audio file exceeds the 15 MB limit.",
        )

    audio_format = normalize_audio_format(file.filename)

    # 2. Retrieve the requested challenge.
    challenge_query = text(
        """
        SELECT
            id,
            target_word_ar,
            target_word_en,
            forbidden_word_ar,
            forbidden_word_en,
            forbidden_words,
            accepted_target_answers,
            difficulty,
            duration_seconds
        FROM dont_say_it_challenges
        WHERE id = :challenge_id
          AND is_active = TRUE
        LIMIT 1
        """
    )

    challenge = db.execute(
        challenge_query,
        {"challenge_id": challenge_id},
    ).mappings().first()

    if not challenge:
        raise HTTPException(
            status_code=404,
            detail="The requested active challenge was not found.",
        )

    forbidden_words = normalize_word_list(
        challenge.get("forbidden_words")
    )

    if not forbidden_words:
        forbidden_words = [
            str(word).strip()
            for word in (
                challenge.get("forbidden_word_ar"),
                challenge.get("forbidden_word_en"),
            )
            if word and str(word).strip()
        ]

    accepted_target_answers = normalize_word_list(
        challenge.get("accepted_target_answers")
    )

    # 3. Transcribe the audio for the first model.
    transcript = transcribe_audio(
        audio_bytes,
        file.filename or f"recording.{audio_format}",
    )

    # 4. Model 1 predicts the target from the transcript only.
    # The original target and forbidden words are not sent here.
    prediction_result = predict_target_word(transcript)

    # 5. Model 2 receives the original recording, target,
    # forbidden words, and model 1's prediction.
    game_result = validate_game(
        audio_bytes=audio_bytes,
        audio_format=audio_format,
        target_word_ar=challenge["target_word_ar"],
        target_word_en=challenge["target_word_en"],
        accepted_target_answers=accepted_target_answers,
        forbidden_words=forbidden_words,
        prediction_result=prediction_result,
    )

    # 6. Run the existing technical speech analyzer separately.
    try:
        analyzer = OpenAIAudioAnalyzer()
        speech_result = analyzer.analyze_audio(
            audio_bytes,
            audio_format,
        )

        if hasattr(speech_result, "model_dump"):
            speech_analysis = speech_result.model_dump()
        elif isinstance(speech_result, dict):
            speech_analysis = speech_result
        else:
            raise TypeError(
                "The speech analyzer returned an unsupported result."
            )

    except UnusableSpeechError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        ) from exc
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Speech analysis failed: {str(exc)}",
        ) from exc

    # 7. Save the attempt.
    user_id = str(current_user.id)

    game_analysis = {
        "prediction": prediction_result,
        "validation": game_result,
        "target_word_spoken": game_result["target_word_spoken"],
        "matched_forbidden_words": game_result[
            "matched_forbidden_words"
        ],
        "transcript": game_result["transcript"] or transcript,
    }

    insert_query = text(
        """
        INSERT INTO dont_say_it_attempts (
            user_id,
            challenge_id,
            target_guessed,
            forbidden_word_spoken,
            passed,
            game_analysis,
            speech_analysis
        )
        VALUES (
            :user_id,
            :challenge_id,
            :target_guessed,
            :forbidden_word_spoken,
            :passed,
            CAST(:game_analysis AS JSONB),
            CAST(:speech_analysis AS JSONB)
        )
        RETURNING id
        """
    )

    try:
        attempt_id = db.execute(
            insert_query,
            {
                "user_id": user_id,
                "challenge_id": challenge_id,
                "target_guessed": game_result["meaning_matched"],
                "forbidden_word_spoken": (
                    game_result["forbidden_word_spoken"]
                    or game_result["target_word_spoken"]
                ),
                "passed": game_result["passed"],
                "game_analysis": json.dumps(
                    game_analysis,
                    ensure_ascii=False,
                ),
                "speech_analysis": json.dumps(
                    speech_analysis,
                    ensure_ascii=False,
                ),
            },
        ).scalar_one()

        db.commit()

    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to save the game attempt: {str(exc)}",
        ) from exc

    # 8. Return the game result and technical speech metrics.
    return {
        "attempt_id": attempt_id,
        "challenge_id": challenge_id,
        "prediction": prediction_result,
        "game_analysis": game_result,
        "passed": game_result["passed"],
        "speech_analysis": speech_analysis,
    }
