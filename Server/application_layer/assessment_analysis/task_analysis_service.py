from data_and_integration_layer.ai_integration.openai_audio import (
    OpenAIAudioAnalyzer,
    AudioAnalysisResult,
)
from data_and_integration_layer.cloud_storage.audio_downloader import (
    AudioDownloader,
)


class TaskAnalysisService:

    def __init__(self):
        self.audio_downloader = AudioDownloader()
        self.audio_analyzer = OpenAIAudioAnalyzer()

    def analyze_task(self, storage_url: str) -> AudioAnalysisResult:
        audio_bytes, audio_format = self.audio_downloader.download_audio(
            storage_url
        )

        result = self.audio_analyzer.analyze_audio(
            audio_bytes,
            audio_format,
        )

        return result