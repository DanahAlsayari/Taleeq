import hashlib
import hmac

from . import auth
from .signup_otp import (
    generate_otp,
    OTP_EXPIRY_SECONDS,
    OTP_RESEND_SECONDS,
    OTP_MAX_ATTEMPTS,
    OTP_MAX_RESENDS,
)

EMAIL_CHANGE_LIFETIME_SECONDS = 1800


def digest_email_change_otp(request_id: str, code: str) -> str:
    if not auth.SECRET_KEY:
        raise RuntimeError("SECRET_KEY is missing.")

    message = f"email_change:{request_id}:{code}".encode("utf-8")

    return hmac.new(
        auth.SECRET_KEY.encode("utf-8"),
        message,
        hashlib.sha256,
    ).hexdigest()


def email_change_otp_matches(
    request_id: str,
    entered_code: str,
    stored_digest: str,
) -> bool:
    entered_digest = digest_email_change_otp(
        request_id,
        entered_code,
    )

    return hmac.compare_digest(
        entered_digest,
        stored_digest,
    )
