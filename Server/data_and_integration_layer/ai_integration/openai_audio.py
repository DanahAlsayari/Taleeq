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
        print("🎧 AUDIO FORMAT SENT TO OPENAI:", audio_format)
        print("🎧 AUDIO BYTES FIRST 20:", audio_bytes[:20])
        print("🎧 BASE64 LENGTH:", len(encoded_audio))
        prompt =   """
Listen carefully to the entire attached Arabic speech recording.

Your task is to analyze the speaker's speech for stuttering.

Detect:
1. Repetition: repeated sounds, syllables, or words.
2. Prolongation: unusually prolonged speech sounds.
3. Block: interruption or inability to initiate or continue speech.

Analyze the actual audio you can hear.
Do not ask for the audio again.
Do not say that you cannot access the recording.

Return ONLY valid JSON in exactly this structure:

{
  "stuttering_percent": 0,
  "repetition_percent": 0,
  "prolongation_percent": 0,
  "block_percent": 0,
  "speaking_rate_wpm": 0,
  "speaking_rate": 0,
  "timing_pacing": 0,
  "speech_events": []
}

For speech_events, use:

{
  "event_type": "repetition | prolongation | block",
  "word_or_sound": "Arabic sound, syllable, or word",
  "confidence": 0.0
}

Rules:
- Analyze the recording from beginning to end.
- Detect every genuine stuttering event you can hear.
- Do not invent events.
- stuttering_percent represents the estimated percentage of speech affected by stuttering.
- repetition_percent, prolongation_percent, and block_percent represent the percentage of overall speech affected by each type.
- speaking_rate_wpm is the estimated words per minute.
- speaking_rate is a 0-100 score for appropriateness and stability of speaking rate.
- timing_pacing is a 0-100 score for stability and naturalness of speech timing and pacing.
- confidence must be between 0 and 1.
"""


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