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
    speaking_rate: float = Field(ge=0.0)
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
            technique_name: str,
            technique_description: str,
            technique_steps: list | dict,
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

Use the exercise instructions and content to understand what
the speaker is expected to do and to evaluate task adherence.


For reading exercises, consider how accurately the speaker follows
the provided text. For other exercise types, evaluate how well the
speaker fulfills the requested task.
Do not require exact wording unless the exercise requires it.

SELECTED TECHNIQUE:
Name: {technique_name}
Description: {technique_description}
Steps: {json.dumps(technique_steps, ensure_ascii=False)}

TECHNIQUE-AWARE EVALUATION:
The user is practicing this technique during the exercise.

Do not penalize intentional speech behaviors consistent
with the technique, including changes in pace, rhythm,
pauses, repetitions, or prolongations.

Exclude technique-consistent intentional behaviors from
stuttering events and percentages. Continue detecting
genuine stuttering when supported by audible evidence.

Evaluate timing, speed control, and task adherence
according to the technique's goals and steps.

Do not assume the technique was performed correctly
or infer intention without sufficient audible evidence.

Keep all existing metrics and scoring rules unchanged.

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
- speaking_rate: estimated number of words spoken in 10 seconds.
- timing_pacing: score from 0 to 100 for naturalness and consistency
  of timing, rhythm, and pauses.

Keep speaking_rate and timing_pacing distinct.
Do not penalize a speaker solely for having a stutter or speaking slowly.
Do not count pauses alone as stuttering. Use zero when no relevant
event is audible. Keep scores consistent with the evidence.


EXERCISE PERFORMANCE SCORES:
Evaluate exercise performance using four scores from 0 to 100.

Two scores are derived from the detailed speech metrics
and must not be independently estimated:

- fluency_score: calculated as 100 minus stuttering_percent.
  This represents fluency based on the estimated percentage
  of speech affected by stuttering.

- rhythm_score: equal to timing_pacing.
  This represents the naturalness and consistency of speech
  timing, rhythm, and pauses.

Evaluate the following two scores independently using
the audible recording and the provided exercise context:

- speed_control_score: how well the speaker maintains an
  appropriate and controlled speaking pace for the assigned
  exercise. Consider the exercise instructions and difficulty.
  Do not reward faster speech simply for being faster.
  Do not invent a target speaking speed if none is specified.

- task_adherence_score: how well the speaker follows the
  exercise instructions and completes the requested content.
  For reading exercises, consider how accurately the speaker
  follows the provided text.
  For other exercise types, evaluate how well the speaker
  fulfills the requested task.
  Do not require exact wording unless the exercise requires it.

Keep speed_control_score and task_adherence_score distinct.

Do not calculate a weighted total score.



FEEDBACK:
Provide exactly one main strength and one main area for
improvement based on the four exercise performance criteria:

- fluency: speech fluency based on stuttering_percent.
- rhythm: speech rhythm and timing based on timing_pacing.
- speed_control: control and appropriateness of speaking pace
  according to the exercise instructions.
- task_adherence: how well the speaker follows the exercise
  instructions and completes the requested content.

STRENGTH:
Identify the strongest aspect of the speaker's performance
among these four criteria.

Select the criterion that shows the clearest positive
performance based on the audible evidence and exercise context.

Provide specific positive feedback directly related to
the selected criterion.

IMPROVEMENT:
Identify the most important area for improvement among
the same four criteria.

Prioritize the criterion that shows the clearest difficulty
or has the greatest impact on completing the exercise.

Provide one specific, practical suggestion directly related
to the selected criterion.

FEEDBACK RULES:
- Base both feedback statements on the four evaluation criteria.
- Do not introduce unrelated feedback topics.
- Consider the estimated speech metrics and the assigned
  exercise requirements when selecting feedback.
- Select only one main strength and one main improvement.
- The strength and improvement should focus on different
  criteria whenever supported by the evidence.
- Do not invent achievements, errors, or speech events.
- Do not automatically treat slow speech, natural pauses,
  or stuttering as failure to complete the exercise.
- Write all feedback in Arabic.
- Keep each statement to 1–2 concise sentences.
- Use a supportive, clear, and constructive tone.
- If there is insufficient evidence for a field,
  return an empty string for that field.


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
    "strength": "",
    "improvement": ""
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
            print("🎯 TECHNIQUE:", technique_name)
            print("📊 ANALYSIS RESULT:", json.dumps(
                result_data,
                ensure_ascii=False,
                indent=2,
            ))

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
