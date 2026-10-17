import os
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr
from pathlib import Path

from dotenv import load_dotenv


SERVER_DIR = Path(__file__).resolve().parents[2]
load_dotenv(SERVER_DIR / ".env")


def send_signup_code(recipient: str, code: str) -> None:
    host = os.getenv("SIGNUP_SMTP_HOST", "smtp.gmail.com")
    port = int(os.getenv("SIGNUP_SMTP_PORT", "465"))
    username = os.getenv("SIGNUP_SMTP_USER")
    password = os.getenv("SIGNUP_SMTP_PASSWORD")
    sender_name = os.getenv("SIGNUP_FROM_NAME", "Taleeq")

    if not username or not password:
        raise RuntimeError("Signup email settings are missing.")

    message = EmailMessage()
    message["Subject"] = "رمز التحقق من بريدك الإلكتروني — طليق"
    message["From"] = formataddr((sender_name, username))
    message["To"] = recipient

    message.set_content(
        f"مرحبًا بك في طليق!\n\n"
        f"رمز التحقق الخاص بك هو: {code}\n\n"
        "إذا لم تطلب إنشاء حساب، يمكنك تجاهل هذه الرسالة.\n"
        "لا تشارك رمز التحقق مع أي شخص."
    )

    context = ssl.create_default_context()

    with smtplib.SMTP_SSL(
        host,
        port,
        context=context,
        timeout=20,
    ) as smtp:
        smtp.login(username, password)
        smtp.send_message(message)