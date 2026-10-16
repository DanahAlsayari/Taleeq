import re
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator


NAME_PATTERN = re.compile(
    r"^[A-Za-z\u0621-\u063A\u0641-\u064A]+"
    r"(?: [A-Za-z\u0621-\u063A\u0641-\u064A]+)*$"
)
PHONE_PATTERN = re.compile(r"^05[0-9]{8}$")
PASSWORD_PATTERN = re.compile(r"^[A-Za-z0-9!@#$%^&*]+$")


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str = Field(min_length=8, max_length=20)
    confirm_password: str = Field(min_length=8, max_length=20)
    phone_number: str
    age: int = Field(ge=13, le=100)
    gender: Literal["female", "male"]

    @field_validator("email")
    @classmethod
    def validate_email_characters(cls, value: EmailStr) -> EmailStr:
        if not str(value).isascii():
            raise ValueError("Email contains invalid characters.")

        return value

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        normalized_name = " ".join(value.strip().split())

        if not NAME_PATTERN.fullmatch(normalized_name):
            raise ValueError("Name contains invalid characters.")

        return normalized_name

    @field_validator("phone_number")
    @classmethod
    def validate_phone_number(cls, value: str) -> str:
        normalized_phone = value.strip()

        if not PHONE_PATTERN.fullmatch(normalized_phone):
            raise ValueError("Invalid phone number.")

        return normalized_phone

    @field_validator("password", "confirm_password")
    @classmethod
    def validate_password_characters(cls, value: str) -> str:
        if not PASSWORD_PATTERN.fullmatch(value):
            raise ValueError("Password contains invalid characters.")

        return value


class UserOut(BaseModel):
    id: int
    name: str
    email: EmailStr
    phone_number: str
    age: int
    gender: str

    class Config:
        from_attributes = True


class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(max_length=20)

    @field_validator("email")
    @classmethod
    def validate_email_characters(cls, value: EmailStr) -> EmailStr:
        if not str(value).isascii():
            raise ValueError("Email contains invalid characters.")

        return value

class Token(BaseModel):
    access_token: str
    token_type: str

class SignupOTPResponse(BaseModel):
    registration_id: str
    message: str
    expires_in_seconds: int
    resend_after_seconds: int


class VerifySignupOTP(BaseModel):
    registration_id: str = Field(min_length=36, max_length=36)
    code: str = Field(pattern=r"^[0-9]{6}$")


class ResendSignupOTP(BaseModel):
    registration_id: str = Field(min_length=36, max_length=36)