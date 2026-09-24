from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.user import User

from . import auth
from . import schemas
from .profile import router as profile_router
from .reset_password import router as reset_password_router


app = FastAPI()

app.include_router(reset_password_router)
app.include_router(profile_router)


@app.post("/signup", response_model=schemas.UserOut)
def signup(
    user: schemas.UserCreate,
    db: Session = Depends(get_db),
):
normalized_email = user.email.strip().lower()
    if user.password != user.confirm_password:
        raise HTTPException(
            status_code=400,
            detail="Passwords do not match.",
        )
    auth.validate_password(user.password)

    existing_user = (
        db.query(User)
        .filter(
            func.lower(User.email) == normalized_email,
        )
        .first()
    )

    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Email already registered",
        )

    new_user = User(
        name=user.name.strip(),
        email=normalized_email,
        password_hash=auth.hash_password(
            user.password,
        ),
        phone_number=user.phone_number.strip(),
        age=user.age,
        gender=user.gender,
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user


@app.post("/login", response_model=schemas.Token)
def login(
    credentials: schemas.UserLogin,
    db: Session = Depends(get_db),
):
    normalized_email = (
        credentials.email.strip().lower()
    )

    user = (
        db.query(User)
        .filter(
            func.lower(User.email) ==
            normalized_email,
        )
        .first()
    )

    if not user or not auth.verify_password(
        credentials.password,
        user.password_hash,
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password",
        )

    token = auth.create_access_token(
        {"sub": user.email},
    )

    return {
        "access_token": token,
        "token_type": "bearer",
    }