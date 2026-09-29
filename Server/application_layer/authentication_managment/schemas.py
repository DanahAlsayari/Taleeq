import re
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator


NAME_PATTERN = re.compile(
    r"^[A-Za-z\u0621-\u063A\u0641-\u064A]+"
    r"(?:[ '\-][A-Za-z\u0621-\u063A\u0641-\u064A]+)*$"
)
PHONE_PATTERN = re.compile(r"^05\d{8}$")


class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=50)
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    confirm_password: str = Field(min_length=8, max_length=72)
    phone_number: str
    age: int = Field(ge=13, le=100)
    gender: Literal["female", "male"]

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
    def validate_password_byte_length(cls, value: str) -> str:
        if len(value.encode("utf-8")) > 72:
            raise ValueError("Password is too long.")

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
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str
