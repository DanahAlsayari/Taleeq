import math
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from data_and_integration_layer.database.models.user import User
from data_and_integration_layer.database.models.pending_email_change import (
    PendingEmailChange,
)

from . import auth, schemas
from .email_change_otp import (
    generate_otp,
    digest_email_change_otp,
    email_change_otp_matches,
    OTP_EXPIRY_SECONDS,
    OTP_RESEND_SECONDS,
    OTP_MAX_ATTEMPTS,
    OTP_MAX_RESENDS,
    EMAIL_CHANGE_LIFETIME_SECONDS,
)
from .signup_email import send_email_change_code


def request_email_change(
    request: schemas.RequestEmailChange,
    current_user: User,
    db: Session,
) -> dict:
    new_email = str(request.new_email).strip().lower()

    if new_email == current_user.email.lower():
        raise HTTPException(
            status_code=400,
            detail="New email must be different from current email.",
        )

    existing_user = db.query(User).filter(func.lower(User.email) == new_email).first()

    if existing_user:
        raise HTTPException(
            status_code=409,
            detail="Email is already registered.",
        )

    now = datetime.now(timezone.utc)

    pending = (
        db.query(PendingEmailChange)
        .filter(PendingEmailChange.user_id == current_user.id)
        .with_for_update()
        .first()
    )

    if pending:
        lifetime_end = pending.created_at + timedelta(
            seconds=EMAIL_CHANGE_LIFETIME_SECONDS,
        )

        if now < lifetime_end:
            raise HTTPException(
                status_code=409,
                detail=(
                    "You already have a pending email change request. "
                    "Please verify it or try again later."
                ),
            )

        db.delete(pending)
        db.flush()

    request_id = str(uuid4())
    code = generate_otp()

    pending = PendingEmailChange(
        id=request_id,
        user_id=current_user.id,
        new_email=new_email,
        otp_digest=digest_email_change_otp(request_id, code),
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
            detail="An email change request already exists.",
        ) from None

    try:
        send_email_change_code(new_email, code)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=503,
            detail="Could not send verification code. Please try again.",
        ) from None

    db.commit()

    return {
        "request_id": request_id,
        "message": "Verification code sent to your new email.",
        "expires_in_seconds": OTP_EXPIRY_SECONDS,
        "resend_after_seconds": OTP_RESEND_SECONDS,
    }


def resend_email_change(
    request: schemas.ResendEmailChangeOTP,
    current_user: User,
    db: Session,
) -> dict:
    pending = (
        db.query(PendingEmailChange)
        .filter(
            PendingEmailChange.id == request.request_id,
            PendingEmailChange.user_id == current_user.id,
        )
        .with_for_update()
        .first()
    )

    if pending is None:
        raise HTTPException(
            status_code=404,
            detail="Email change request not found.",
        )

    now = datetime.now(timezone.utc)

    lifetime_end = pending.created_at + timedelta(
        seconds=EMAIL_CHANGE_LIFETIME_SECONDS,
    )

    if now >= lifetime_end:
        raise HTTPException(
            status_code=410,
            detail="Email change request expired. Please start again.",
        )

    if pending.failed_attempts >= OTP_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=429,
            detail="Maximum verification attempts exceeded.",
        )

    if pending.resend_count >= OTP_MAX_RESENDS:
        raise HTTPException(
            status_code=429,
            detail="Maximum resend attempts exceeded.",
        )

    cooldown_end = pending.last_sent_at + timedelta(
        seconds=OTP_RESEND_SECONDS,
    )

    if now < cooldown_end:
        remaining_seconds = math.ceil((cooldown_end - now).total_seconds())

        raise HTTPException(
            status_code=429,
            detail=(
                f"Please wait {remaining_seconds} seconds "
                "before requesting another code."
            ),
            headers={"Retry-After": str(remaining_seconds)},
        )

    existing_user = (
        db.query(User).filter(func.lower(User.email) == pending.new_email).first()
    )

    if existing_user:
        raise HTTPException(
            status_code=409,
            detail="Email is already registered.",
        )

    code = generate_otp()

    pending.otp_digest = digest_email_change_otp(
        pending.id,
        code,
    )
    pending.expires_at = min(
        now + timedelta(seconds=OTP_EXPIRY_SECONDS),
        lifetime_end,
    )
    pending.last_sent_at = now
    pending.resend_count += 1

    try:
        send_email_change_code(pending.new_email, code)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=503,
            detail="Could not resend verification code.",
        ) from None

    db.commit()

    return {
        "request_id": pending.id,
        "message": "A new verification code has been sent.",
        "expires_in_seconds": max(
            0,
            math.ceil((pending.expires_at - now).total_seconds()),
        ),
        "resend_after_seconds": OTP_RESEND_SECONDS,
    }


def verify_email_change(
    request: schemas.VerifyEmailChangeOTP,
    current_user: User,
    db: Session,
) -> dict:
    pending = (
        db.query(PendingEmailChange)
        .filter(
            PendingEmailChange.id == request.request_id,
            PendingEmailChange.user_id == current_user.id,
        )
        .with_for_update()
        .first()
    )

    if pending is None:
        raise HTTPException(
            status_code=404,
            detail="Email change request not found or already used.",
        )

    now = datetime.now(timezone.utc)

    lifetime_end = pending.created_at + timedelta(
        seconds=EMAIL_CHANGE_LIFETIME_SECONDS,
    )

    if now >= lifetime_end:
        raise HTTPException(
            status_code=410,
            detail="Email change request expired. Please start again.",
        )

    if pending.failed_attempts >= OTP_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=429,
            detail="Maximum verification attempts exceeded.",
        )

    if now >= pending.expires_at:
        raise HTTPException(
            status_code=410,
            detail="Verification code expired. Please request a new code.",
        )

    if not email_change_otp_matches(
        pending.id,
        request.code,
        pending.otp_digest,
    ):
        pending.failed_attempts += 1
        attempts_remaining = OTP_MAX_ATTEMPTS - pending.failed_attempts

        db.commit()

        raise HTTPException(
            status_code=400,
            detail=(
                "Incorrect verification code. "
                f"Remaining attempts: {attempts_remaining}"
            ),
        )

    existing_user = (
        db.query(User).filter(func.lower(User.email) == pending.new_email).first()
    )

    if existing_user:
        raise HTTPException(
            status_code=409,
            detail="Email is already registered.",
        )

    new_email = pending.new_email

    new_token = auth.create_access_token({"sub": new_email})

    current_user.email = new_email
    db.delete(pending)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Email is already registered.",
        ) from None

    return {
        "message": "Email updated successfully.",
        "email": new_email,
        "access_token": new_token,
        "token_type": "bearer",
    }
