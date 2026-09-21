from pydantic import BaseModel, EmailStr

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    phone_number: str
    age: int
    gender: str

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