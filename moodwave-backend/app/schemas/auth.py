from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field, field_validator

_COMMON_PASSWORDS = {
    "12345678", "password", "qwerty123", "11111111", "abcdefgh",
    "password1", "123456789", "12345679", "iloveyou", "sunshine",
    "princess", "football", "welcome1", "monkey123", "dragon123",
}

_PASSWORD_ERROR = (
    "Password must be at least 8 characters and include uppercase, lowercase, and a number"
)


def _validate_password(v: str) -> str:
    if len(v) < 8:
        raise ValueError(_PASSWORD_ERROR)
    if not any(c.isupper() for c in v):
        raise ValueError(_PASSWORD_ERROR)
    if not any(c.islower() for c in v):
        raise ValueError(_PASSWORD_ERROR)
    if not any(c.isdigit() for c in v):
        raise ValueError(_PASSWORD_ERROR)
    if v.lower() in _COMMON_PASSWORDS:
        raise ValueError(_PASSWORD_ERROR)
    return v


class RegisterRequest(BaseModel):
    email: EmailStr
    username: str
    password: str
    first_name: Optional[str] = Field(default=None, max_length=100)
    last_name: Optional[str] = Field(default=None, max_length=100)
    display_name: Optional[str] = Field(default=None, max_length=100)
    birth_date: Optional[date] = None
    city: Optional[str] = Field(default=None, max_length=100)

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        return _validate_password(v)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class VerifyEmailRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6)


class ResendVerificationRequest(BaseModel):
    email: EmailStr


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class VerifyResetCodeRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6)


class ResetPasswordRequest(BaseModel):
    reset_token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        return _validate_password(v)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1)
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        return _validate_password(v)


class UserResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    email: str
    username: str
    first_name: Optional[str]
    last_name: Optional[str]
    display_name: Optional[str]
    avatar_url: Optional[str]
    bio: Optional[str]
    birth_date: Optional[date]
    city: Optional[str]
    gender: Optional[str] = None
    avatar_preset: int = 0
    banner_preset: int = 0
    is_public: bool
    show_activity: bool
    is_verified: bool
    is_active: bool
    is_admin: bool = False
    genres: list[str] = []
    moods: list[str] = []
    created_at: datetime


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponse
