from pydantic import BaseModel, EmailStr, Field, field_validator

from app.models.user import UserRole


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    role: UserRole = UserRole.customer
    interests: list[str] = Field(default_factory=list)
    # The privacy policy version the user read and agreed to on the sign-up form.
    privacy_policy_version: str = Field(max_length=32)

    @field_validator("role")
    @classmethod
    def _no_self_service_admin(cls, role: UserRole) -> UserRole:
        # SEC-3: admin accounts are created by the seed or directly in the
        # database, never through public sign-up.
        if role == UserRole.admin:
            raise ValueError("Admin accounts can't be created through sign-up")
        return role


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class GoogleAuthRequest(BaseModel):
    id_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


_OTP_PATTERN = r"^\d{6}$"


class VerifyEmailRequest(BaseModel):
    code: str = Field(pattern=_OTP_PATTERN)


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class VerifyResetOtpRequest(BaseModel):
    email: EmailStr
    code: str = Field(pattern=_OTP_PATTERN)


class ResetPasswordRequest(BaseModel):
    reset_token: str
    new_password: str = Field(min_length=8, max_length=128)


class OtpSentResponse(BaseModel):
    expires_in_minutes: int
    resend_cooldown_seconds: int


class ResetTokenResponse(BaseModel):
    reset_token: str
    expires_in_minutes: int


class MessageResponse(BaseModel):
    message: str
