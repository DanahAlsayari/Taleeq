import requests
from urllib.parse import urlparse


SUPPORTED_FORMATS = {
    "wav": "wav",
    "mp3": "mp3",
    "m4a": "m4a",
    "webm": "webm",
}


class AudioDownloader:

    def download_audio(self, storage_url: str) -> tuple[bytes, str]:
        parsed_url = urlparse(storage_url)

        if parsed_url.scheme not in {"http", "https"}:
            raise ValueError("Invalid storage URL.")

        response = requests.get(storage_url, timeout=30)

        if response.status_code != 200:
            raise ValueError(
                f"Failed to download audio. Status code: {response.status_code}"
            )

        audio_format = self._get_audio_format(parsed_url.path)

        return response.content, audio_format

    def _get_audio_format(self, path: str) -> str:
        extension = path.rsplit(".", 1)[-1].lower()

        if extension not in SUPPORTED_FORMATS:
            raise ValueError(
                f"Unsupported audio format: {extension}"
            )

        return SUPPORTED_FORMATS[extension]