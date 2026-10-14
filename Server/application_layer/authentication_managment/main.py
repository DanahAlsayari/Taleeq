from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from .signup_otp import (
    resend_signup,
    start_signup,
    verify_signup,
)

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


@app.post("/signup", response_model=schemas.SignupOTPResponse)
def signup(
    user: schemas.UserCreate,
    db: Session = Depends(get_db),
):
    return start_signup(user, db)

@app.post("/signup/verify", response_model=schemas.Token)
def verify_signup_email(
    request: schemas.VerifySignupOTP,
    db: Session = Depends(get_db),
):
    return verify_signup(request, db)

@app.post(
    "/signup/resend",
    response_model=schemas.SignupOTPResponse,
)
def resend_signup_email(
    request: schemas.ResendSignupOTP,
    db: Session = Depends(get_db),
):
    return resend_signup(request, db)
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