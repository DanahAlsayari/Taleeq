
import base64
import io
import json
import os
import re
from typing import Literal

import numpy as np
import soundfile as sf
import webrtcvad
from dotenv import load_dotenv
from openai import OpenAI
from pydantic import BaseModel, Field, ConfigDict

load_dotenv()


# =========================================================
# Response Models
# =========================================================

class SpeechEvent(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event_type: Literal["repetition", "prolongation", "block"]
    word_or_sound: str
    confidence: float = Field(ge=0.0, le=1.0)


class AudioAnalysisResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    stuttering_percent: float = Field(ge=0.0, le=100.0)
    repetition_percent: float = Field(ge=0.0, le=100.0)
    prolongation_percent: float = Field(ge=0.0, le=100.0)
    block_percent: float = Field(ge=0.0, le=100.0)

    speaking_rate_wpm: float | None = Field(default=None, ge=0.0)
    speaking_rate: float = Field(ge=0.0, le=100.0)
    timing_pacing: float = Field(ge=0.0, le=100.0)

    speech_events: list[SpeechEvent] = Field(default_factory=list)


class AudioAnalysisResponse(AudioAnalysisResult):
    speech_usable: bool
    validation_reason: str = ""


class UnusableSpeechError(ValueError):
    """Raised when a recording cannot be analyzed reliably."""


# =========================================================
# Audio Analyzer
# =========================================================

class OpenAIAudioAnalyzer:

    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")

        if not api_key:
            raise ValueError(
                "OPENAI_API_KEY is not set in the environment variables."
            )

        self.client = OpenAI(api_key=api_key)
        self.model = "gpt-audio-1.5"

    # =====================================================
    # Stage 1: Read and validate the audio signal
    # =====================================================

    def _load_audio(self, audio_bytes: bytes):
        if not audio_bytes:
            raise UnusableSpeechError("التسجيل فارغ. أعيدي التسجيل.")

        try:
            audio, sample_rate = sf.read(
                io.BytesIO(audio_bytes),
                dtype="float32",
                always_2d=False,
            )
        except Exception as error:
            raise UnusableSpeechError(
                "تعذرت قراءة التسجيل الصوتي. "
                "جرّبي تسجيله بصيغة WAV أو MP3."
            ) from error

        if audio.size == 0 or sample_rate <= 0:
            raise UnusableSpeechError("التسجيل فارغ أو غير صالح.")

        # Convert stereo to mono.
        if audio.ndim == 2:
            audio = np.mean(audio, axis=1)

        audio = np.nan_to_num(
            audio,
            nan=0.0,
            posinf=0.0,
            neginf=0.0,
        )
        audio = np.clip(audio, -1.0, 1.0)

        if audio.ndim != 1 or not np.any(np.isfinite(audio)):
            raise UnusableSpeechError(
                "تعذرت قراءة الإشارة الصوتية."
            )

        return audio, sample_rate

    # =====================================================
    # Stage 2: Detect silence and extremely weak audio
    # =====================================================

    def _validate_audio(self, audio_bytes: bytes) -> None:
        audio, sample_rate = self._load_audio(audio_bytes)

        duration = len(audio) / sample_rate

        print("AUDIO DURATION:", round(duration, 2))
        print("SAMPLE RATE:", sample_rate)

        if duration < 5.0:
            raise UnusableSpeechError(
                "التسجيل قصير جدًا. حاولي التحدث لمدة أطول."
            )

        # Analyze consecutive 100 ms windows.
        window_size = max(1, int(sample_rate * 0.1))
        rms_values = []
        peak_values = []

        for start in range(0, len(audio), window_size):
            window = audio[start:start + window_size]

            if window.size == 0:
                continue

            rms_values.append(
                float(np.sqrt(np.mean(np.square(window))))
            )
            peak_values.append(
                float(np.max(np.abs(window)))
            )

        if not rms_values:
            raise UnusableSpeechError(
                "لم يتم العثور على صوت في التسجيل."
            )

        rms = np.asarray(rms_values)
        peaks = np.asarray(peak_values)

        max_rms = float(np.max(rms))
        max_peak = float(np.max(peaks))

        # Initial thresholds; calibrate against real recordings.
        MIN_MAX_RMS = 0.003
        MIN_MAX_PEAK = 0.015

        # Count windows with a meaningful signal.
        active_mask = (
            (rms >= 0.003)
            | (peaks >= 0.015)
        )

        active_windows = int(np.sum(active_mask))
        active_duration = active_windows * 0.1

        print("MAX RMS:", max_rms)
        print("MAX PEAK:", max_peak)
        print("ACTIVE WINDOWS:", active_windows)
        print("ACTIVE DURATION:", round(active_duration, 2))

        if (
            max_rms < MIN_MAX_RMS
            or max_peak < MIN_MAX_PEAK
            or active_duration < 0.3
        ):
            raise UnusableSpeechError(
                "مستوى الصوت منخفض جدًا "
                "تأكد من الميكروفون ثم أعد التسجيل."
            )

        # Continue with speech-activity detection.
        self._validate_speech_activity(audio, sample_rate)

    # =====================================================
    # Stage 3: Detect possible speech activity with WebRTC VAD
    # =====================================================

    def _validate_speech_activity(
        self,
        audio: np.ndarray,
        sample_rate: int,
    ) -> None:

        target_rate = 16000

        # Resample to 16 kHz when necessary.
        if sample_rate != target_rate:
            target_length = int(
                len(audio) * target_rate / sample_rate
            )

            if target_length <= 0:
                raise UnusableSpeechError(
                    "تعذر تحليل التسجيل الصوتي."
                )

            old_positions = np.arange(len(audio))
            new_positions = (
                np.arange(target_length)
                * sample_rate
                / target_rate
            )

            audio = np.interp(
                new_positions,
                old_positions,
                audio,
            ).astype(np.float32)

        # WebRTC VAD requires 16-bit PCM audio.
        pcm = (audio * 32767).astype("<i2").tobytes()

        # 30 ms frames at 16 kHz.
        frame_samples = 480
        frame_bytes = frame_samples * 2

        vad = webrtcvad.Vad(2)

        total_frames = 0
        voiced_frames = 0

        for start in range(
            0,
            len(pcm) - frame_bytes + 1,
            frame_bytes,
        ):
            frame = pcm[start:start + frame_bytes]
            total_frames += 1

            if vad.is_speech(frame, target_rate):
                voiced_frames += 1

        voiced_duration = voiced_frames * 0.03
        voiced_ratio = (
            voiced_frames / total_frames
            if total_frames
            else 0.0
        )

        print("VAD VOICED DURATION:", round(voiced_duration, 2))
        print("VAD VOICED RATIO:", round(voiced_ratio, 3))

        if voiced_duration < 0.3 or voiced_ratio < 0.02:
            raise UnusableSpeechError(
                "لم نتمكن من اكتشاف كلام كافٍ في التسجيل. "
                "تأكد من الميكروفون وابتعد عن الضوضاء ثم أعد التسجيل."
            )

    # =====================================================
    # Stage 4: Parse the AI response safely
    # =====================================================

    @staticmethod
    def _parse_json_response(content: str) -> dict:
        content = content.strip()

        # Remove optional Markdown code fences.
        content = re.sub(
            r"^\s*```(?:json)?\s*",
            "",
            content,
            flags=re.IGNORECASE,
        )
        content = re.sub(r"\s*```\s*$", "", content)

        try:
            result = json.loads(content)
        except json.JSONDecodeError:
            # Recover a JSON object if extra text surrounds it.
            start = content.find("{")
            end = content.rfind("}")

            if start == -1 or end <= start:
                raise ValueError(
                    "OpenAI returned an invalid JSON response."
                )

            try:
                result = json.loads(content[start:end + 1])
            except json.JSONDecodeError as error:
                raise ValueError(
                    "OpenAI returned an invalid JSON response."
                ) from error

        if not isinstance(result, dict):
            raise ValueError(
                "OpenAI response must be a JSON object."
            )

        return result

    # =====================================================
    # Stage 5: Analyze speech and stuttering
    # =====================================================

    def analyze_audio(
        self,
        audio_bytes: bytes,
        audio_format: str,
    ) -> AudioAnalysisResult:

        # Technical checks run before sending audio to the AI.
        self._validate_audio(audio_bytes)

        print("AUDIO VALIDATION PASSED — CALLING OPENAI")

        encoded_audio = base64.b64encode(
            audio_bytes
        ).decode("utf-8")

        prompt = """
You are Taleeq's audio-based speech fluency analyzer.
Analyze the entire Arabic speech recording using only audible evidence.

AUDIO USABILITY:
Determine whether speech is sufficiently intelligible for reliable
analysis. Reject silence, extremely weak audio, severe distortion,
dominant noise, or unintelligible speech.

Accept understandable speech even when quiet or affected by stuttering.
Do not confuse natural pauses, breathing, or thinking with silence.
Do not confuse stuttering with unintelligibility.

If unusable, set speech_usable to false, explain in arabic briefly in
validation_reason, set all percentage and score metrics to 0,
set speaking_rate_wpm to null, and return an empty speech_events array.

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
- speaking_rate: a score from 0 to 100 representing the
  appropriateness and stability of speaking rate.
- timing_pacing: score from 0 to 100 for naturalness and consistency
  of timing, rhythm, and pauses.

Keep speaking_rate and timing_pacing distinct.
Do not penalize a speaker solely for having a stutter or speaking slowly.
Do not count pauses alone as stuttering. Use zero when no relevant
event is audible. Keep scores consistent with the evidence.

These metrics are estimates, not clinical measurements or diagnoses.

OUTPUT:
Return only one valid JSON object with exactly these keys:
{
  "speech_usable": true,
  "validation_reason": "",
  "stuttering_percent": 0.0,
  "repetition_percent": 0.0,
  "prolongation_percent": 0.0,
  "block_percent": 0.0,
  "speaking_rate_wpm": 0.0,
  "speaking_rate": 0.0,
  "timing_pacing": 0.0,
  "speech_events": []
}

Use a boolean for speech_usable and a string for validation_reason.
Percentages and timing_pacing must be between 0 and 100.
speaking_rate must be a number between 0 and 100.
speaking_rate_wpm must be a non-negative number or null.
Each speech_events item must contain exactly:
{
  "event_type": "repetition",
  "word_or_sound": "audible sound or word",
  "confidence": 0.0
}

event_type must be repetition, prolongation, or block.
Confidence must be between 0.0 and 1.0.
Always include all required keys. Use valid JSON only, without
Markdown or additional explanation.
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
            raise ValueError(
                "OpenAI returned an empty response."
            )

        result_data = self._parse_json_response(content)

        print("OPENAI RAW RESULT:", result_data)

        # Validate field names, types, ranges, and event categories.
        response_data = AudioAnalysisResponse.model_validate(
            result_data
        )

        if not response_data.speech_usable:
            reason = response_data.validation_reason.strip()

            if not reason:
                reason = (
                    "لم نتمكن من سماع كلام واضح بما يكفي "
                    "لتحليل التسجيل."
                )

            raise UnusableSpeechError(reason)

        if not response_data.validation_reason.strip() == "":
            print(
                "WARNING: Usable recording has a validation reason:",
                response_data.validation_reason,
            )

        analysis_data = response_data.model_dump(
            exclude={
                "speech_usable",
                "validation_reason",
            }
        )

        return AudioAnalysisResult.model_validate(analysis_data)
