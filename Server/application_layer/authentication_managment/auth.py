import os
from datetime import datetime, timedelta

import bcrypt
from fastapi import Depends, HTTPException
from fastapi.security import (
    HTTPAuthorizationCredentials,
    HTTPBearer,
)
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.user import User


SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60
SPECIAL_CHARACTERS = "!@#$%^&*"

security = HTTPBearer()


def validate_password(password: str) -> None:
    if len(password) < 8:
        raise HTTPException(
            status_code=400,
            detail=(
                "Password must be at least "
                "8 characters."
            ),
        )

    if not any(char.isupper() for char in password):
        raise HTTPException(
            status_code=400,
            detail=(
                "Password must contain at least "
                "one uppercase letter."
            ),
        )

    if not any(char.islower() for char in password):
        raise HTTPException(
            status_code=400,
            detail=(
                "Password must contain at least "
                "one lowercase letter."
            ),
        )

    if not any(char.isdigit() for char in password):
        raise HTTPException(
            status_code=400,
            detail=(
                "Password must contain at least "
                "one number."
            ),
        )

    if not any(
        char in SPECIAL_CHARACTERS
        for char in password
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "Password must contain at least one "
                "special character (!@#$%^&*)."
            ),
        )


def hash_password(password: str) -> str:
    password_bytes = password.encode("utf-8")

    hashed = bcrypt.hashpw(
        password_bytes,
        bcrypt.gensalt(),
    )

    return hashed.decode("utf-8")


def verify_password(
    plain_password: str,
    hashed_password: str,
) -> bool:
    plain_bytes = plain_password.encode("utf-8")
    hashed_bytes = hashed_password.encode("utf-8")

    return bcrypt.checkpw(
        plain_bytes,
        hashed_bytes,
    )


def create_access_token(data: dict) -> str:
    to_encode = data.copy()

    expire = datetime.utcnow() + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES,
    )

    to_encode.update({"exp": expire})

    return jwt.encode(
        to_encode,
        SECRET_KEY,
        algorithm=ALGORITHM,
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(
        security,
    ),
    db: Session = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=401,
        detail="Invalid or expired token",
    )

    try:
        payload = jwt.decode(
            credentials.credentials,
            SECRET_KEY,
            algorithms=[ALGORITHM],
        )

        email = payload.get("sub")

        if not email:
            raise credentials_exception

    except JWTError:
        raise credentials_exception

    user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if not user:
        raise credentials_exception

    return user