from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.security import (
    PASSWORD_RESET_TOKEN,
    REFRESH_TOKEN,
    create_access_token,
    create_password_reset_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_google_id_token,
    verify_password,
)
from app.models.otp import OtpPurpose
from app.models.user import User, UserRole
from app.schemas.auth import (
    ForgotPasswordRequest,
    GoogleAuthRequest,
    LoginRequest,
    MessageResponse,
    OtpSentResponse,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    ResetTokenResponse,
    TokenPair,
    VerifyEmailRequest,
    VerifyResetOtpRequest,
)
from app.schemas.user import UserOut
from app.services import otp_service

router = APIRouter(prefix="/auth", tags=["auth"])


def _tokens_for(user: User) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(
    payload: RegisterRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)
) -> User:
    exists = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if exists:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Email already registered"
        )
    user = User(
        email=payload.email,
        full_name=payload.full_name,
        hashed_password=hash_password(payload.password),
        role=payload.role,
        interests=payload.interests,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    otp_service.create_and_send(db, user, OtpPurpose.verify_email, background_tasks)
    return user


@router.post("/login", response_model=TokenPair)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenPair:
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password"
        )
    return _tokens_for(user)


@router.post("/login/form", response_model=TokenPair, include_in_schema=False)
def login_form(
    form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)
) -> TokenPair:
    """OAuth2 password-flow endpoint so Swagger's Authorize button works."""
    user = db.execute(select(User).where(User.email == form.username)).scalar_one_or_none()
    if user is None or not verify_password(form.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password"
        )
    return _tokens_for(user)


@router.post("/google", response_model=TokenPair)
def google_login(payload: GoogleAuthRequest, db: Session = Depends(get_db)) -> TokenPair:
    claims = verify_google_id_token(payload.id_token)
    if claims is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google ID token"
        )
    google_id = claims["sub"]
    email = claims.get("email")
    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Google account has no email"
        )

    user = db.execute(select(User).where(User.google_id == google_id)).scalar_one_or_none()
    if user is None:
        user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
        if user is not None:
            user.google_id = google_id
            user.is_verified = True  # Google already proved ownership of this email
        else:
            user = User(
                email=email,
                full_name=claims.get("name") or email.split("@")[0],
                hashed_password=None,
                google_id=google_id,
                role=UserRole.customer,
                is_verified=True,
            )
            db.add(user)
        db.commit()
        db.refresh(user)
    return _tokens_for(user)


@router.post("/refresh", response_model=TokenPair)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)) -> TokenPair:
    data = decode_token(payload.refresh_token)
    if data is None or data.get("type") != REFRESH_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token"
        )
    user = db.get(User, int(data["sub"]))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token"
        )
    return _tokens_for(user)


# ─────────────────────────── email verification ───────────────────────────


@router.post("/email/verify/send", response_model=OtpSentResponse)
def send_verification_email(
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OtpSentResponse:
    if user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Email is already verified"
        )
    cooldown = otp_service.create_and_send(db, user, OtpPurpose.verify_email, background_tasks)
    return OtpSentResponse(
        expires_in_minutes=settings.OTP_EXPIRE_MINUTES, resend_cooldown_seconds=cooldown
    )


@router.post("/email/verify", response_model=UserOut)
def verify_email(
    payload: VerifyEmailRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    if not user.is_verified:
        otp_service.verify_code(db, user, OtpPurpose.verify_email, payload.code)
        user.is_verified = True
        db.commit()
        db.refresh(user)
    return user


# ─────────────────────────── forgot / reset password ───────────────────────────


@router.post("/password/forgot", response_model=OtpSentResponse)
def forgot_password(
    payload: ForgotPasswordRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)
) -> OtpSentResponse:
    generic = OtpSentResponse(
        expires_in_minutes=settings.OTP_EXPIRE_MINUTES,
        resend_cooldown_seconds=settings.OTP_RESEND_COOLDOWN_SECONDS,
    )
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    # Google-only accounts have no password to reset. Respond identically to the
    # unknown-email case either way, so this endpoint can't be used to enumerate
    # registered emails.
    if user is None or user.hashed_password is None:
        return generic
    cooldown = otp_service.create_and_send(db, user, OtpPurpose.reset_password, background_tasks)
    return OtpSentResponse(
        expires_in_minutes=settings.OTP_EXPIRE_MINUTES, resend_cooldown_seconds=cooldown
    )


@router.post("/password/forgot/verify", response_model=ResetTokenResponse)
def verify_reset_otp(
    payload: VerifyResetOtpRequest, db: Session = Depends(get_db)
) -> ResetTokenResponse:
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Incorrect code.")
    otp_service.verify_code(db, user, OtpPurpose.reset_password, payload.code)
    return ResetTokenResponse(
        reset_token=create_password_reset_token(user.id),
        expires_in_minutes=settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES,
    )


@router.post("/password/reset", response_model=MessageResponse)
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)) -> MessageResponse:
    data = decode_token(payload.reset_token)
    if data is None or data.get("type") != PASSWORD_RESET_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired reset token"
        )
    user = db.get(User, int(data["sub"]))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired reset token"
        )
    user.hashed_password = hash_password(payload.new_password)
    db.commit()
    return MessageResponse(message="Password updated. You can now sign in.")
