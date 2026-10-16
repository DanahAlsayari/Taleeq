from typing import Any
import os
import base64
import json
from pydantic import BaseModel, Field, ConfigDict
from dotenv import load_dotenv
from openai import OpenAI
from data_and_integration_layer.ai_integration.openai_audio import (
    OpenAIAudioAnalyzer,
    SpeechEvent,
    UnusableSpeechError,
)


load_dotenv()




# =========================================================
# Response model
# =========================================================


class ExerciseAnalysisResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    fluency_score: float = Field(ge=0.0, le=100.0)
    rhythm_score: float = Field(ge=0.0, le=100.0)
    speed_control_score: float = Field(ge=0.0, le=100.0)
    task_adherence_score: float = Field(ge=0.0, le=100.0)

    stuttering_percent: float = Field(ge=0.0, le=100.0)
    repetition_percent: float = Field(ge=0.0, le=100.0)
    prolongation_percent: float = Field(ge=0.0, le=100.0)
    block_percent: float = Field(ge=0.0, le=100.0)

    speaking_rate_wpm: float | None = Field(default=None, ge=0.0)
    speaking_rate: float = Field(ge=0.0, le=100.0)
    timing_pacing: float = Field(ge=0.0, le=100.0)

    feedback: dict[str, Any]
    raw_openai_response: dict[str, Any]
    speech_events: list[SpeechEvent] = Field(default_factory=list)




# =========================================================
# Audio Analyzer
# =========================================================

class OpenAIExerciseAnalyzer:

    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")

        if not api_key:
            raise ValueError(
                "OPENAI_API_KEY is not set in the environment variables."
            )

        self.client = OpenAI(api_key=api_key)
        self.model = "gpt-audio-1.5"
        self.audio_validator = OpenAIAudioAnalyzer()



    @staticmethod
    def _parse_json_response(content: str) -> dict:
        return OpenAIAudioAnalyzer._parse_json_response(content)



    def analyze_audio(
            self,
            audio_bytes: bytes,
            audio_format: str,
            exercise_type: str,
            difficulty: str,
            content: dict,
            instructions: str,
        ) -> ExerciseAnalysisResult:
            self.audio_validator._validate_audio(audio_bytes)

            print("AUDIO VALIDATION PASSED — CALLING OPENAI")


            prompt = f"""
You are Taleeq's audio-based speech fluency analyzer.
Analyze the entire Arabic speech recording using only audible evidence.

EXERCISE CONTEXT:
Evaluate the recording according to the assigned speech exercise.

Exercise type: {exercise_type}
Difficulty: {difficulty}
Instructions: {instructions}
Exercise content: {json.dumps(content, ensure_ascii=False)}

Use the exercise instructions and content to evaluate task adherence.
For reading exercises, consider how accurately the speaker follows
the provided text. For other exercise types, evaluate how well the
speaker fulfills the requested task.
Do not require exact wording unless the exercise requires it.

AUDIO USABILITY:
Determine whether speech is sufficiently intelligible for reliable
analysis. Reject silence, extremely weak audio, severe distortion,
dominant noise, or unintelligible speech.

Accept understandable speech even when quiet or affected by stuttering.
Do not confuse natural pauses, breathing, or thinking with silence.
Do not confuse stuttering with unintelligibility.

If unusable, set speech_usable to false, explain briefly in
validation_reason, set all percentage and score metrics to 0,
set speaking_rate_wpm to null, return an empty speech_events array,
and provide empty strings for all feedback fields.

STUTTERING EVENTS:
Identify only genuine audible events:

- repetition: involuntary repetition of sounds, syllables, or words.
- prolongation: an unusually extended sound consistent with stuttering.
- block: an audible difficulty initiating or continuing a sound or word.

Do not infer blocks from silence alone. Do not classify ordinary
breathing, thinking pauses, emphasis, or self-corrections as stuttering
without supporting evidence. Never invent or duplicate events.

For each event, provide event_type, word_or_sound, and confidence
between 0.0 and 1.0. If an event is uncertain, omit it rather than guess.

METRICS:
Estimate these values from the entire usable recording:

- stuttering_percent: estimated percentage of speech affected by stuttering.
- repetition_percent: estimated percentage affected by repetitions.
- prolongation_percent: estimated percentage affected by prolongations.
- block_percent: estimated percentage affected by blocks.
- speaking_rate_wpm: estimated spoken words per minute, or null if unreliable.
- speaking_rate: score from 0 to 100 for appropriateness and consistency
  of speaking rate.
- timing_pacing: score from 0 to 100 for naturalness and consistency
  of timing, rhythm, and pauses.

Keep speaking_rate and timing_pacing distinct.
Do not penalize a speaker solely for having a stutter or speaking slowly.
Do not count pauses alone as stuttering. Use zero when no relevant
event is audible. Keep scores consistent with the evidence.

EXERCISE PERFORMANCE SCORES:
Evaluate these four criteria from 0 to 100:

- fluency_score: overall smoothness and continuity of speech,
  considering stuttering events and disruptions without treating
  stuttering_percent as the fluency score itself.

- rhythm_score: consistency and naturalness of speech rhythm,
  including timing and pauses.

- speed_control_score: ability to maintain an appropriate,
  controlled speaking pace for the assigned exercise.
  Do not reward speaking faster simply for being faster.

- task_adherence_score: how well the speaker follows the
  exercise instructions and completes the requested content.
  Consider the exercise type and difficulty.

Keep these four scores distinct from the detailed speech metrics.
Do not calculate a weighted total score; the backend calculates it.

FEEDBACK:
Provide brief, constructive feedback in Arabic for each criterion:

- fluency: feedback about fluency and one practical improvement.
- rhythm: feedback about rhythm and one practical improvement.
- speed_control: feedback about speaking pace and control.
- task_adherence: feedback about completing the assigned exercise.

Base all feedback on the actual recording and exercise context.
Do not invent errors, missed words, or stuttering events.

These metrics and scores are estimates, not clinical measurements
or diagnoses.

OUTPUT:
Return only one valid JSON object with exactly these keys:
{{
  "speech_usable": true,
  "validation_reason": "",
  "stuttering_percent": 0.0,
  "repetition_percent": 0.0,
  "prolongation_percent": 0.0,
  "block_percent": 0.0,
  "speaking_rate_wpm": null,
  "speaking_rate": 0.0,
  "timing_pacing": 0.0,
  "speech_events": [],
  "fluency_score": 0.0,
  "rhythm_score": 0.0,
  "speed_control_score": 0.0,
  "task_adherence_score": 0.0,
  "feedback": {{
    "fluency": "",
    "rhythm": "",
    "speed_control": "",
    "task_adherence": ""
  }}
}}

The values above describe the JSON structure, not fixed scores.
Evaluate the actual recording and exercise instructions.

Use a boolean for speech_usable, a string for validation_reason,
numbers from 0 to 100 for percentages and scores, and a non-negative
number or null for speaking_rate_wpm.

Each speech_events item must contain exactly:
{{
  "event_type": "repetition",
  "word_or_sound": "audible sound or word",
  "confidence": 0.0
}}

event_type must be repetition, prolongation, or block.
Confidence must be between 0.0 and 1.0.

Always include all required keys. Use valid JSON only, without
Markdown or additional explanation.
"""

            encoded_audio = base64.b64encode(
                audio_bytes
            ).decode("utf-8")

            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": prompt,
                            },
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

            response_content = response.choices[0].message.content

            if not response_content:
                raise ValueError("OpenAI returned an empty response.")

            result_data = self._parse_json_response(response_content)

            # Check speech usable.
            if not isinstance(result_data.get("speech_usable"), bool):
                raise ValueError("Invalid speech_usable value.")

            if not result_data["speech_usable"]:
                raise UnusableSpeechError(
                    result_data.get("validation_reason")
                    or "لم نتمكن من تحليل التسجيل الصوتي."
                )

            raw_response = result_data.copy()

  
            result_data.pop("speech_usable")
            result_data.pop("validation_reason", None)

            result_data["raw_openai_response"] = raw_response

            return ExerciseAnalysisResult.model_validate(result_data)
