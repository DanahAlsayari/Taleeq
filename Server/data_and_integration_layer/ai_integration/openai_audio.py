import base64
import json
import os
import webrtcvad
from dotenv import load_dotenv
from openai import OpenAI
from pydantic import BaseModel, Field

import io
import numpy as np
import soundfile as sf
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


class AudioAnalysisResponse(BaseModel):
    speech_usable: bool
    validation_reason: str = ""

    stuttering_percent: float = Field(ge=0.0, le=100.0)
    repetition_percent: float = Field(ge=0.0, le=100.0)
    prolongation_percent: float = Field(ge=0.0, le=100.0)
    block_percent: float = Field(ge=0.0, le=100.0)

    speaking_rate_wpm: float | None = None
    speaking_rate: float = Field(ge=0.0, le=100.0)
    timing_pacing: float = Field(ge=0.0, le=100.0)

    speech_events: list[SpeechEvent] = Field(default_factory=list)

class UnusableSpeechError(ValueError):
    pass

class OpenAIAudioAnalyzer:

    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")

        if not api_key:
            raise ValueError(
                "OPENAI_API_KEY is not set in the environment variables."
            )

        self.client = OpenAI(api_key=api_key)
        self.model = "gpt-audio-1.5"


    def _is_silent(self, audio_bytes: bytes) -> bool:
        print("🚨 _is_silent() CALLED")

        try:
            audio, sample_rate = sf.read(
                io.BytesIO(audio_bytes),
                dtype="float32",
                always_2d=False,
            )
        except Exception as error:
            raise ValueError(
                "تعذرت قراءة التسجيل الصوتي."
            ) from error

        if audio.size == 0:
            print("🔇 AUDIO IS EMPTY")
            return True

        # تحويل التسجيل إلى قناة صوتية واحدة
        if audio.ndim == 2:
            audio = np.mean(audio, axis=1)

        audio = np.nan_to_num(audio)

        # تقسيم التسجيل إلى نوافذ مدة كل منها 100ms
        window_size = max(1, int(sample_rate * 0.1))
        rms_values = []
        peak_values = []

        for start in range(0, len(audio), window_size):
            window = audio[start:start + window_size]

            if window.size == 0:
                continue

            rms = float(np.sqrt(np.mean(window ** 2)))
            peak = float(np.max(np.abs(window)))

            rms_values.append(rms)
            peak_values.append(peak)

        if not rms_values:
            print("🔇 NO VALID AUDIO WINDOWS")
            return True

        max_rms = max(rms_values)
        median_rms = float(np.median(rms_values))
        max_peak = max(peak_values)

        active_windows = sum(
            1
            for rms, peak in zip(rms_values, peak_values)
            if rms > 0.0005 or peak > 0.002
        )

        print("🔍 SAMPLE RATE:", sample_rate)
        print("🔍 AUDIO DURATION:", len(audio) / sample_rate)
        print("🔊 MAX RMS:", max_rms)
        print("🔊 MEDIAN RMS:", median_rms)
        print("🔊 MAX PEAK:", max_peak)
        print("🔍 ACTIVE WINDOWS:", active_windows, "/", len(rms_values))

        # حد مبدئي لمستوى الصوت المنخفض جدًا
        MIN_MEDIAN_RMS = 0.015

        if median_rms < MIN_MEDIAN_RMS:
            print("🔇 AUDIO REJECTED: VOLUME TOO LOW")
            return True

        print("✅ AUDIO LEVEL PASSED")
        return False

    def _contains_speech(self, audio_bytes: bytes) -> bool:
        try:
            audio, sample_rate = sf.read(
                io.BytesIO(audio_bytes),
                dtype="float32",
                always_2d=False,
            )
        except Exception as error:
            raise ValueError("تعذرت قراءة التسجيل الصوتي.") from error

        if audio.size == 0:
            return False

        if audio.ndim == 2:
            audio = np.mean(audio, axis=1)

        audio = np.nan_to_num(audio)
        audio = np.clip(audio, -1.0, 1.0)

        target_rate = 16000

        if sample_rate != target_rate:
            target_length = int(len(audio) * target_rate / sample_rate)

            if target_length == 0:
                return False

            old_positions = np.arange(len(audio))
            new_positions = (
                np.arange(target_length) * sample_rate / target_rate
            )

            audio = np.interp(
                new_positions, old_positions, audio
            ).astype(np.float32)

        frame_size = 480  # 30 ms عند 16 kHz
        frame_bytes = frame_size * 2
        pcm_audio = (audio * 32767).astype("<i2").tobytes()

        vad = webrtcvad.Vad(2)
        total_frames = 0
        voiced_frames = 0
        flatness_values = []

        for start in range(
            0, len(pcm_audio) - frame_bytes + 1, frame_bytes
        ):
            frame_bytes_data = pcm_audio[start:start + frame_bytes]
            frame = np.frombuffer(frame_bytes_data, dtype="<i2").astype(
                np.float32
            ) / 32768.0

            total_frames += 1

            if vad.is_speech(frame_bytes_data, target_rate):
                voiced_frames += 1

            # مؤشر طيفي تقريبي؛ لا يحدد الكلام بمفرده.
            spectrum = np.abs(np.fft.rfft(frame * np.hanning(len(frame)))) ** 2
            spectrum = spectrum[1:]  # تجاهل التردد الصفري

            if spectrum.size:
                spectrum += 1e-12
                flatness = float(
                    np.exp(np.mean(np.log(spectrum)))
                    / np.mean(spectrum)
                )
                flatness_values.append(flatness)

        if total_frames == 0 or not flatness_values:
            return False

        voiced_duration = voiced_frames * 0.03
        voiced_ratio = voiced_frames / total_frames
        median_flatness = float(np.median(flatness_values))
        frame_rms_values = []

        for start in range(
            0, len(pcm_audio) - frame_bytes + 1, frame_bytes
        ):
            frame = np.frombuffer(
                pcm_audio[start:start + frame_bytes],
                dtype="<i2",
            ).astype(np.float32) / 32768.0

            frame_rms_values.append(
                float(np.sqrt(np.mean(frame ** 2)))
            )

        rms_variation = float(np.std(frame_rms_values))
        rms_median = float(np.median(frame_rms_values))
        rms_cv = rms_variation / (rms_median + 1e-8)

        print("🔊 RMS COEFFICIENT OF VARIATION:", rms_cv)

        steady_noise_suspected = (
            voiced_ratio >= 0.95
            and rms_cv < 0.35
            and median_flatness < 0.005
        )

        print("⚠️ STEADY NOISE SUSPECTED:", steady_noise_suspected)
        print("🔊 RMS MEDIAN:", rms_median)
        print("🔊 RMS VARIATION:", rms_variation)
        print("🗣️ VAD VOICED DURATION:", voiced_duration)
        print("🗣️ VAD VOICED RATIO:", voiced_ratio)
        print("🔊 MEDIAN SPECTRAL FLATNESS:", median_flatness)

        # شرط VAD الأساسي، مع الاحتفاظ به كما كان.
        vad_passed = voiced_duration >= 0.5 and voiced_ratio >= 0.03

        # مؤشر تشخيصي للضوضاء الثابتة.
        # لا نرفض التسجيل بناءً على هذا المؤشر وحده.
        noise_suspected = (
            voiced_ratio >= 0.80
            and median_flatness >= 0.65
        )

        print("⚠️ NOISE SUSPECTED:", noise_suspected)

        # مؤقتًا: نطبع الاشتباه فقط حتى نختبر تسجيلات حقيقية.
        return vad_passed

    def analyze_audio(
        self,
        audio_bytes: bytes,
        audio_format: str,
    ) -> AudioAnalysisResult:

        if self._is_silent(audio_bytes):
            raise UnusableSpeechError(
                "عذرًا، التسجيل صامت أو لا يحتوي على صوت مسموع. "
                "يرجى التحدث بوضوح ثم إعادة التسجيل."
            )
        print("🧪 RUNNING VAD BEFORE OPENAI")

        if not self._contains_speech(audio_bytes):
            raise UnusableSpeechError(
                "عذرًا، لم نتمكن من اكتشاف كلام واضح في التسجيل. "
                "تأكدي من عمل الميكروفون وتحدثي بوضوح ثم أعيدي التسجيل."
            )
        print("🧪 VAD PASSED — CALLING OPENAI")

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
  "speech_usable": true,
  "validation_reason": "",
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
- Determine whether the recording contains audible human speech that is
  sufficiently clear to analyze.
- Set "speech_usable" to false for silence, background noise only,
  or audio where speech is too unclear to analyze reliably.
- Set "speech_usable" to true when meaningful speech is audible,
  even if the speaker stutters, repeats sounds or words, prolongs sounds,
  experiences blocks, hesitates, or pauses.
- If speech is not usable, explain briefly in "validation_reason".
- If speech is usable, set "validation_reason" to an empty string.

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
        print("🔍 OPENAI RAW RESULT:", result_data)
        response_data = AudioAnalysisResponse.model_validate(
            result_data
        )

        if not response_data.speech_usable:
            raise UnusableSpeechError(
                "عذرًا، لم نتمكن من سماع كلام واضح بما يكفي لتحليل التسجيل. "
                "يرجى التأكد من عمل الميكروفون والتحدث بوضوح ثم إعادة التسجيل."
            )

        analysis_data = response_data.model_dump(
            exclude={"speech_usable", "validation_reason"}
        )

        return AudioAnalysisResult.model_validate(analysis_data)
