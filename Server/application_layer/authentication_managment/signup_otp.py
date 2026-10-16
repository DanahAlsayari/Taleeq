import hashlib
import hmac
import secrets
import math

from . import auth
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from data_and_integration_layer.database.models.user import User
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError

from data_and_integration_layer.database.models.pending_registration import (
    PendingRegistration,
)

from . import schemas
from .signup_email import send_signup_code


OTP_EXPIRY_SECONDS = 600       # Code expires after 10 minutes.
OTP_RESEND_SECONDS = 60        # Wait 1 minute before resending.
OTP_MAX_ATTEMPTS = 5           # Maximum incorrect attempts.
OTP_MAX_RESENDS = 3            # Maximum resends per registration.
REGISTRATION_LIFETIME_SECONDS = 1800  # Pending registration: 30 minutes.


def generate_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def digest_otp(registration_id: str, code: str) -> str:
    if not auth.SECRET_KEY:
        raise RuntimeError("SECRET_KEY is missing.")

    message = f"signup:{registration_id}:{code}".encode("utf-8")

    return hmac.new(
        auth.SECRET_KEY.encode("utf-8"),
        message,
        hashlib.sha256,
    ).hexdigest()


def otp_matches(
    registration_id: str,
    entered_code: str,
    stored_digest: str,
) -> bool:
    entered_digest = digest_otp(registration_id, entered_code)

    return hmac.compare_digest(entered_digest, stored_digest)

def registered_account_detail(
    db: Session,
    email: str,
    phone_number: str,
) -> str | None:
    existing_users = (
        db.query(User)
        .filter(
            or_(
                func.lower(User.email) == email,
                User.phone_number == phone_number,
            )
        )
        .all()
    )

    email_used = any(
        existing.email.lower() == email
        for existing in existing_users
    )

    phone_used = any(
        existing.phone_number == phone_number
        for existing in existing_users
    )

    if email_used and phone_used:
        return "Email and phone number already registered"

    if email_used:
        return "Email already registered"

    if phone_used:
        return "Phone number already registered"

    return None

def start_signup(
    user: schemas.UserCreate,
    db: Session,
) -> dict:
    email = str(user.email).strip().lower()
    phone = user.phone_number.strip()

    if user.password != user.confirm_password:
        raise HTTPException(
            status_code=400,
            detail="Passwords do not match.",
        )

    auth.validate_password(user.password)

    duplicate_detail = registered_account_detail(db, email, phone)

    if duplicate_detail:
        raise HTTPException(
            status_code=400,
            detail=duplicate_detail,
        )

    now = datetime.now(timezone.utc)

    existing_pending = (
        db.query(PendingRegistration)
        .filter(PendingRegistration.email == email)
        .with_for_update()
        .first()
    )

    if existing_pending is not None:
        lifetime_end = existing_pending.created_at + timedelta(
            seconds=REGISTRATION_LIFETIME_SECONDS,
        )

        if now < lifetime_end:
            raise HTTPException(
                status_code=409,
                detail=(
                    "يوجد طلب تسجيل قيد التحقق لهذا البريد. "
                    "يرجى إكمال التحقق أو المحاولة لاحقًا."
                ),
            )

        db.delete(existing_pending)
        db.flush()

    registration_id = str(uuid4())
    code = generate_otp()

    pending = PendingRegistration(
        id=registration_id,
        name=user.name.strip(),
        email=email,
        password_hash=auth.hash_password(user.password),
        phone_number=phone,
        age=user.age,
        gender=user.gender,
        otp_digest=digest_otp(registration_id, code),
        expires_at=now + timedelta(seconds=OTP_EXPIRY_SECONDS),
        failed_attempts=0,
        resend_count=0,
        created_at=now,
        last_sent_at=now,
    )

    db.add(pending)

    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="يوجد طلب تسجيل قيد التحقق لهذا البريد.",
        ) from None

    try:
        send_signup_code(email, code)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=503,
            detail="تعذر إرسال رمز التحقق. يرجى المحاولة مرة أخرى.",
        ) from None

    db.commit()

    return {
        "registration_id": registration_id,
        "message": "تم إرسال رمز التحقق إلى بريدك الإلكتروني",
        "expires_in_seconds": OTP_EXPIRY_SECONDS,
        "resend_after_seconds": OTP_RESEND_SECONDS,
    }

def resend_signup(
    request: schemas.ResendSignupOTP,
    db: Session,
) -> dict:
    pending = (
        db.query(PendingRegistration)
        .filter(
            PendingRegistration.id == request.registration_id,
        )
        .with_for_update()
        .first()
    )

    if pending is None:
        raise HTTPException(
            status_code=400,
            detail="طلب التسجيل غير موجود أو تم استخدامه بالفعل.",
        )

    now = datetime.now(timezone.utc)

    lifetime_end = pending.created_at + timedelta(
        seconds=REGISTRATION_LIFETIME_SECONDS,
    )

    if now >= lifetime_end:
        raise HTTPException(
            status_code=410,
            detail="انتهت صلاحية طلب التسجيل. يرجى التسجيل من جديد.",
        )

    if pending.failed_attempts >= OTP_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=429,
            detail="تم تجاوز عدد محاولات التحقق المسموح بها.",
        )

    if pending.resend_count >= OTP_MAX_RESENDS:
        raise HTTPException(
            status_code=429,
            detail="تم تجاوز عدد مرات إعادة إرسال الرمز المسموح بها.",
        )

    cooldown_end = pending.last_sent_at + timedelta(
        seconds=OTP_RESEND_SECONDS,
    )

    if now < cooldown_end:
        remaining_seconds = math.ceil(
            (cooldown_end - now).total_seconds()
        )

        raise HTTPException(
            status_code=429,
            detail=(
                "يرجى الانتظار "
                f"{remaining_seconds} ثانية قبل طلب رمز جديد."
            ),
            headers={"Retry-After": str(remaining_seconds)},
        )

    duplicate_detail = registered_account_detail(
        db,
        pending.email,
        pending.phone_number,
    )

    if duplicate_detail:
        raise HTTPException(
            status_code=400,
            detail=duplicate_detail,
        )

    code = generate_otp()

    pending.otp_digest = digest_otp(pending.id, code)
    pending.expires_at = min(
        now + timedelta(seconds=OTP_EXPIRY_SECONDS),
        lifetime_end,
    )
    pending.last_sent_at = now
    pending.resend_count += 1

    response = {
        "registration_id": pending.id,
        "message": "تم إرسال رمز تحقق جديد إلى بريدك الإلكتروني",
        "expires_in_seconds": max(
            0,
            math.ceil(
                (pending.expires_at - now).total_seconds()
            ),
        ),
        "resend_after_seconds": OTP_RESEND_SECONDS,
    }

    try:
        send_signup_code(pending.email, code)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=503,
            detail="تعذر إرسال رمز التحقق. يرجى المحاولة مرة أخرى.",
        ) from None

    db.commit()

    return response

def verify_signup(
    request: schemas.VerifySignupOTP,
    db: Session,
) -> dict:
    pending = (
        db.query(PendingRegistration)
        .filter(
            PendingRegistration.id == request.registration_id,
        )
        .with_for_update()
        .first()
    )

    if pending is None:
        raise HTTPException(
            status_code=400,
            detail="طلب التسجيل غير موجود أو تم استخدامه بالفعل.",
        )

    now = datetime.now(timezone.utc)

    lifetime_end = pending.created_at + timedelta(
        seconds=REGISTRATION_LIFETIME_SECONDS,
    )

    if now >= lifetime_end:
        raise HTTPException(
            status_code=410,
            detail="انتهت صلاحية طلب التسجيل. يرجى التسجيل من جديد.",
        )

    if pending.failed_attempts >= OTP_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=429,
            detail=(
                "تم تجاوز عدد المحاولات المسموح بها. "
                "يرجى المحاولة بعد انتهاء صلاحية طلب التسجيل."
            ),
        )

    if now >= pending.expires_at:
        raise HTTPException(
            status_code=410,
            detail="انتهت صلاحية الرمز. يرجى طلب رمز جديد.",
        )

    if not otp_matches(
        pending.id,
        request.code,
        pending.otp_digest,
    ):
        pending.failed_attempts += 1
        attempts_remaining = (
            OTP_MAX_ATTEMPTS - pending.failed_attempts
        )

        db.commit()

        raise HTTPException(
            status_code=400,
            detail=(
                "رمز التحقق غير صحيح. "
                f"المحاولات المتبقية: {attempts_remaining}"
            ),
        )

    email = pending.email
    phone = pending.phone_number

    duplicate_detail = registered_account_detail(
        db,
        email,
        phone,
    )

    if duplicate_detail:
        raise HTTPException(
            status_code=400,
            detail=duplicate_detail,
        )

    new_user = User(
        name=pending.name,
        email=email,
        password_hash=pending.password_hash,
        phone_number=phone,
        age=pending.age,
        gender=pending.gender,
    )

    token = auth.create_access_token({"sub": email})

    db.add(new_user)
    db.delete(pending)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()

        duplicate_detail = registered_account_detail(
            db,
            email,
            phone,
        )

        raise HTTPException(
            status_code=400,
            detail=(
                duplicate_detail
                or "تعذر إنشاء الحساب باستخدام البيانات المدخلة."
            ),
        ) from None

    return {
        "access_token": token,
        "token_type": "bearer",
    }