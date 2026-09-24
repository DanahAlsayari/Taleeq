import base64
import json
import os

from dotenv import load_dotenv
from openai import OpenAI
from pydantic import BaseModel, Field


load_dotenv()


class SpeechEvent(BaseModel):
    event_type: str
    word_or_sound: str | None = None
    confidence: float = Field(ge=0.0, le=1.0)


class AudioAnalysisResult(BaseModel):
    stuttering_percent: float = Field(ge=0.0, le=100.0)
    repetition_percent: float = Field(ge=0.0, le=100.0)
    prolongation_percent: float = Field(ge=0.0, le=100.0)
    block_percent: float = Field(ge=0.0, le=100.0)
    #float 
    speaking_rate_wpm: float | None = None
    speaking_rate: float = Field(ge=0.0, le=100.0)
    timing_pacing: float = Field(ge=0.0, le=100.0)
    speech_events: list[SpeechEvent] = []



class OpenAIAudioAnalyzer:

    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")

        if not api_key:
            raise ValueError(
                "OPENAI_API_KEY is not set in the environment variables."
            )

        self.client = OpenAI(api_key=api_key)
        self.model = "gpt-audio-1.5"

    def analyze_audio(
        self,
        audio_bytes: bytes,
        audio_format: str,
    ) -> AudioAnalysisResult:

        encoded_audio = base64.b64encode(audio_bytes).decode("utf-8")

        prompt = """
Analyze the entire Arabic speech recording for stuttering.

Detect EVERY genuine stuttering event throughout the full recording.
Do not return only the most obvious events.

Stuttering types:
- repetition: involuntary repetition of a sound, syllable, or word
- prolongation: abnormally prolonged speech sound
- block: clear inability or interruption when initiating or continuing speech

For every detected event, provide:
- event_type
- word_or_sound in Arabic when identifiable
- confidence

Also provide:
- stuttering_percent: estimated percentage of the overall speech affected
  by stuttering compare to fluent speech
- repetition_percent: estimated percentage of the overall speech affected
  by repetition
- prolongation_percent: estimated percentage of the overall speech
  affected by prolongation
- block_percent: estimated percentage of the overall speech affected
  by blocks
- speaking_rate_wpm

- speaking_rate: 0-100 score representing how appropriate and stable
  the speaking rate is.
  80-100 = appropriate and stable speaking rate
  60-79 = moderately appropriate, with some noticeable variation
  0-59 = noticeably irregular or inappropriate speaking rate

- timing_pacing: 0-100 score representing the overall stability and
  naturalness of speech timing and pacing, considering pauses,
  interruptions, and rhythm.
  80-100 = stable and natural timing and pacing
  60-79 = moderately stable, with some noticeable disruptions
  0-59 = noticeably disrupted or irregular timing and pacing

The four stuttering percentages must describe the overall speech, not the
distribution of stuttering events. They do not need to add up to 100%.
The three type percentages should generally be consistent with the overall
stuttering percentage.

Analyze the recording from beginning to end and check again for missed
events before returning the result.

Return ONLY valid JSON:

{
  "stuttering_percent": number,
  "repetition_percent": number,
  "prolongation_percent": number,
  "block_percent": number,
  "speaking_rate_wpm": number or null,
  "speaking_rate": number,
  "timing_pacing": number,
  "speech_events": [
    {
      "event_type": "repetition | prolongation | block",
      "word_or_sound": "Arabic sound, syllable, or word",
      "confidence": number
    }
  ]
}

"""

        response = self.client.chat.completions.create(
            model=self.model,
            modalities=["text"],
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

        content = response.choices[0].message.content

        if not content:
            raise ValueError("OpenAI returned an empty response.")

        try:
            result_data = json.loads(content)
        except json.JSONDecodeError as error:
            raise ValueError(
                f"OpenAI returned invalid JSON: {content}"
            ) from error

        return AudioAnalysisResult.model_validate(result_data)