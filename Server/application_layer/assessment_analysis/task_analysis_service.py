from data_and_integration_layer.ai_integration.openai_audio import (
    OpenAIAudioAnalyzer,
    AudioAnalysisResult,
)



class TaskAnalysisService:

    def __init__(self):

        self.audio_analyzer = OpenAIAudioAnalyzer()

    # ---------------------------------------------------------
    # OLD FLOW - FROM STORAGE URL
    # ---------------------------------------------------------

    def analyze_task(
        self,
        storage_url: str,
    ) -> AudioAnalysisResult:

        audio_bytes, audio_format = (
            self.audio_downloader.download_audio(
                storage_url
            )
        )

        result = self.audio_analyzer.analyze_audio(
            audio_bytes,
            audio_format,
        )

        return result

    # ---------------------------------------------------------
    # NEW FLOW - DIRECT AUDIO BYTES
    # ---------------------------------------------------------

    def analyze_audio_bytes(
        self,
        audio_bytes: bytes,
        audio_format: str,
    ) -> AudioAnalysisResult:

        print("🎙️ ANALYZING AUDIO DIRECTLY")
        print("📦 AUDIO SIZE:", len(audio_bytes))
        print("🎵 AUDIO FORMAT:", audio_format)

        result = self.audio_analyzer.analyze_audio(
            audio_bytes,
            audio_format,
        )

        print("✅ AUDIO ANALYSIS SUCCESS")

        return result