from data_and_integration_layer.ai_integration.openai_audio import (
    OpenAIAudioAnalyzer,
    AudioAnalysisResult,
)



class TaskAnalysisService:

    def __init__(self):

        self.audio_analyzer = OpenAIAudioAnalyzer()

   
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