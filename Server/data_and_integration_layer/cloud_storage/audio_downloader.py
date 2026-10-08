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
        print("🔗 DOWNLOADING URL:", storage_url)
        response = requests.get(
            storage_url,
            timeout=30,
        )
        print("📡 RESPONSE STATUS:", response.status_code)
        print("📦 RESPONSE SIZE:", len(response.content))
        if response.status_code != 200:
            raise ValueError(
                f"Failed to download audio. "
                f"Status code: {response.status_code}"
            )

        audio_format = self._detect_audio_format(
            response.content
        )
        print("🎵 DETECTED FORMAT:", audio_format)
        print("🎵 FIRST 20 BYTES:", response.content[:20])
        return response.content, audio_format

    def _detect_audio_format(self, audio_bytes: bytes) -> str:

        # WAV
        if audio_bytes.startswith(b"RIFF") and audio_bytes[8:12] == b"WAVE":
            return "wav"

        # MP3
        if audio_bytes.startswith(b"ID3"):
            return "mp3"

        # MP3 without ID3 metadata
        if len(audio_bytes) >= 2:
            if audio_bytes[0] == 0xFF and (
                audio_bytes[1] & 0xE0
            ) == 0xE0:
                return "mp3"

        # M4A / MP4
        if len(audio_bytes) >= 12:
            if audio_bytes[4:8] == b"ftyp":
                return "m4a"

        # WebM
        if audio_bytes.startswith(b"\x1A\x45\xDF\xA3"):
            return "webm"

        raise ValueError(
            "Could not determine the audio format."
        )