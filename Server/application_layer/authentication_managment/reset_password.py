from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from urllib.parse import quote
import os
import smtplib

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from jose import ExpiredSignatureError, JWTError, jwt
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.user import User
from . import auth


# =========================================================
# Reset Password Settings
# =========================================================

SECRET_KEY = os.getenv("SECRET_KEY")

if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY is not configured.")

ALGORITHM = "HS256"
RESET_TOKEN_EXPIRE_MINUTES = 15
SPECIAL_CHARACTERS = "!@#$%^&*"


# =========================================================
# Gmail / SMTP Settings
# =========================================================

SMTP_HOST = os.getenv("SMTP_HOST")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")


# =========================================================
# Public HTTPS URL
# =========================================================

# Temporary Cloudflare URL.
# We will replace this with a new URL when testing.
PUBLIC_BASE_URL = (
    "https://saturn-costumes-desired-board.trycloudflare.com"
)


# =========================================================
# Authentication Router
# =========================================================

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


# =========================================================
# Request Models
# =========================================================

class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str
    confirm_password: str


# =========================================================
# Create Reset Token
# =========================================================

def create_reset_token(email: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=RESET_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        "sub": email,
        "purpose": "password_reset",
        "exp": expire,
    }

    return jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM,
    )


# =========================================================
# Send Reset Password Email
# =========================================================

def send_reset_email(email: str, reset_token: str) -> None:
    encoded_token = quote(reset_token, safe="")

    reset_link = (
        f"{PUBLIC_BASE_URL}/auth/open-reset"
        f"?token={encoded_token}"
    )

    message = EmailMessage()

    message["Subject"] = "Taleeq - Reset Password"
    message["From"] = SMTP_USER
    message["To"] = email

    # Plain text version
    message.set_content(
        f"""Hello,

We received a request to reset your Taleeq password.

Reset your password using this link:

{reset_link}

This link will expire in 15 minutes.

If you did not request a password reset, you can ignore this email.

Taleeq Team
"""
    )

    # HTML version
    message.add_alternative(
        f"""
<!DOCTYPE html>
<html>
<body style="
    font-family: Arial, sans-serif;
    background-color: #f5f5f5;
    padding: 30px;
">

    <div style="
        max-width: 500px;
        margin: auto;
        background-color: white;
        padding: 30px;
        border-radius: 12px;
    ">

        <h2>Taleeq - Reset Password</h2>

        <p>
            We received a request to reset your Taleeq password.
        </p>

        <p>
            Click the button below to create a new password.
        </p>

        <div style="
            text-align: center;
            margin: 30px 0;
        ">
            <a
                href="{reset_link}"
                style="
                    display: inline-block;
                    background-color: #2563eb;
                    color: white;
                    padding: 14px 28px;
                    text-decoration: none;
                    border-radius: 8px;
                    font-weight: bold;
                "
            >
                Reset Password
            </a>
        </div>

        <p>
            This link will expire in 15 minutes.
        </p>

        <p>
            If you did not request a password reset,
            you can ignore this email.
        </p>

        <p>Taleeq Team</p>

    </div>

</body>
</html>
""",
        subtype="html",
    )

    with smtplib.SMTP(
        SMTP_HOST,
        SMTP_PORT,
    ) as server:
        server.starttls()

        server.login(
            SMTP_USER,
            SMTP_PASSWORD,
        )

        server.send_message(message)


# =========================================================
# Open Taleeq Reset Screen
# =========================================================

@router.get("/open-reset", response_class=HTMLResponse)
def open_reset(token: str):
    encoded_token = quote(token, safe="")

    deep_link = (
        f"taleeq://reset-password?token={encoded_token}"
    )

    return HTMLResponse(
        content=f"""
<!DOCTYPE html>
<html>

<head>
    <meta
        name="viewport"
        content="width=device-width, initial-scale=1"
    >

    <title>Opening Taleeq</title>
</head>

<body style="
    font-family: Arial, sans-serif;
    text-align: center;
    padding: 40px;
">

    <h2>Opening Taleeq...</h2>

    <p>
        If Taleeq does not open automatically,
        click the button below.
    </p>

    <a
        href="{deep_link}"
        style="
            display: inline-block;
            background-color: #2563eb;
            color: white;
            padding: 14px 28px;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
        "
    >
        Open Taleeq
    </a>

    <script>
        setTimeout(function() {{
            window.location.href = "{deep_link}";
        }}, 500);
    </script>

</body>
</html>
"""
    )


# =========================================================
# Forgot Password Endpoint
# =========================================================

@router.post("/forgot-password")
def forgot_password(
    request: ForgotPasswordRequest,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(
        User.email == request.email
    ).first()

    if user:
        reset_token = create_reset_token(user.email)

        send_reset_email(
            user.email,
            reset_token,
        )

    # Same response whether the account exists or not.
    return {
        "message": (
            "If an account exists with this email, "
            "a password reset link will be sent."
        )
    }


# =========================================================
# Reset Password Endpoint
# =========================================================

@router.post("/reset-password")
def reset_password(
    request: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    # -----------------------------------------------------
    # Check Password Match
    # -----------------------------------------------------

    if request.new_password != request.confirm_password:
        raise HTTPException(
            status_code=400,
            detail="Passwords do not match.",
        )

    # -----------------------------------------------------
    # Password Requirements
    # -----------------------------------------------------

    if len(request.new_password) < 8:
        raise HTTPException(
            status_code=400,
            detail="Password must be at least 8 characters.",
        )

    if not any(
        char.isupper()
        for char in request.new_password
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "Password must contain at least "
                "one uppercase letter."
            ),
        )

    if not any(
        char.islower()
        for char in request.new_password
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "Password must contain at least "
                "one lowercase letter."
            ),
        )

    if not any(
        char.isdigit()
        for char in request.new_password
    ):
        raise HTTPException(
            status_code=400,
            detail="Password must contain at least one number.",
        )

    if not any(
        char in SPECIAL_CHARACTERS
        for char in request.new_password
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "Password must contain at least one special "
                "character (!@#$%^&*)."
            ),
        )

    # -----------------------------------------------------
    # Verify Reset Token
    # -----------------------------------------------------

    try:
        payload = jwt.decode(
            request.token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
        )

        if payload.get("purpose") != "password_reset":
            raise HTTPException(
                status_code=400,
                detail="Invalid reset token.",
            )

        email = payload.get("sub")

        if not email:
            raise HTTPException(
                status_code=400,
                detail="Invalid reset token.",
            )

    except ExpiredSignatureError:
        raise HTTPException(
            status_code=400,
            detail="Reset link has expired.",
        )

    except JWTError:
        raise HTTPException(
            status_code=400,
            detail="Invalid reset token.",
        )

    # -----------------------------------------------------
    # Find User
    # -----------------------------------------------------

    user = db.query(User).filter(
        User.email == email
    ).first()

    if not user:
        raise HTTPException(
            status_code=400,
            detail="Invalid reset request.",
        )

    # -----------------------------------------------------
    # Hash + Save New Password
    # -----------------------------------------------------

    user.password_hash = auth.hash_password(
        request.new_password
    )

    db.commit()

    return {
        "message": "Password reset successfully."
    }