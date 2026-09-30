from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from data_and_integration_layer.database.connection import get_db

# Important:
# Load the Assessment model before SQLAlchemy configures User relationships.
from data_and_integration_layer.database.models import assessment
from data_and_integration_layer.database.models.user import User

from . import auth
from . import schemas
from .profile import router as profile_router
from .reset_password import router as reset_password_router

# Assessment routes
from api.assessment import router as assessment_router


app = FastAPI()

app.include_router(reset_password_router)
app.include_router(profile_router)
app.include_router(assessment_router)


@app.post("/signup", response_model=schemas.UserOut)
def signup(
    user: schemas.UserCreate,
    db: Session = Depends(get_db),
):
    normalized_email = user.email.strip().lower()
    normalized_phone = user.phone_number.strip()

    if user.password != user.confirm_password:
        raise HTTPException(
            status_code=400,
            detail="Passwords do not match.",
        )

    auth.validate_password(user.password)

    def registered_account_detail():
        existing_users = (
            db.query(User)
            .filter(
                or_(
                    func.lower(User.email) == normalized_email,
                    User.phone_number == normalized_phone,
                )
            )
            .all()
        )
        email_used = any(
            existing.email.lower() == normalized_email
            for existing in existing_users
        )
        phone_used = any(
            existing.phone_number == normalized_phone
            for existing in existing_users
        )
        if email_used and phone_used:
            return "Email and phone number already registered"
        if email_used:
            return "Email already registered"
        if phone_used:
            return "Phone number already registered"
        return None

    duplicate_detail = registered_account_detail()
    if duplicate_detail:
        raise HTTPException(
            status_code=400,
            detail=duplicate_detail,
        )

    new_user = User(
        name=user.name.strip(),
        email=normalized_email,
        password_hash=auth.hash_password(user.password),
        phone_number=normalized_phone,
        age=user.age,
        gender=user.gender,
    )

    db.add(new_user)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail=(registered_account_detail() or "Account information cannot be used"),
        ) from None

    db.refresh(new_user)

    return new_user


@app.post("/login", response_model=schemas.Token)
def login(
    credentials: schemas.UserLogin,
    db: Session = Depends(get_db),
):
    normalized_email = credentials.email.strip().lower()

    user = (
        db.query(User)
        .filter(
            func.lower(User.email) == normalized_email,
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