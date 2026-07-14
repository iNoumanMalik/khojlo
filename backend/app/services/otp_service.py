import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import BackgroundTasks, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.otp import OtpCode, OtpPurpose
from app.models.user import User
from app.services.email_service import send_password_reset_otp, send_verify_email_otp


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: datetime) -> datetime:
    """SQLite (used in tests) drops tzinfo on round-trip even for tz-aware columns;
    treat naive values as UTC, matching how they were written."""
    return dt if dt.tzinfo is not None else dt.replace(tzinfo=timezone.utc)


def _hash_code(code: str) -> str:
    return hmac.new(settings.SECRET_KEY.encode(), code.encode(), hashlib.sha256).hexdigest()


def _generate_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _latest_for(db: Session, user_id: int, purpose: OtpPurpose) -> OtpCode | None:
    return db.execute(
        select(OtpCode)
        .where(OtpCode.user_id == user_id, OtpCode.purpose == purpose)
        .order_by(OtpCode.created_at.desc())
        .limit(1)
    ).scalar_one_or_none()


def create_and_send(
    db: Session,
    user: User,
    purpose: OtpPurpose,
    background_tasks: BackgroundTasks,
) -> int:
    """Creates a fresh OTP for the user, emails it, and returns the resend cooldown in seconds.

    Raises HTTP 429 if the caller is within the cooldown window or has exceeded the
    daily send cap.
    """
    now = _utcnow()
    cooldown = timedelta(seconds=settings.OTP_RESEND_COOLDOWN_SECONDS)

    latest = _latest_for(db, user.id, purpose)
    if latest is not None and now - _aware(latest.created_at) < cooldown:
        retry_after = int((_aware(latest.created_at) + cooldown - now).total_seconds())
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Please wait {retry_after}s before requesting a new code.",
        )

    window_start = now - timedelta(hours=24)
    sent_today = db.execute(
        select(OtpCode).where(
            OtpCode.user_id == user.id,
            OtpCode.purpose == purpose,
            OtpCode.created_at >= window_start,
        )
    ).scalars().all()
    if len(sent_today) >= settings.OTP_MAX_PER_DAY:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many codes requested. Please try again later.",
        )

    code = _generate_code()
    otp = OtpCode(
        user_id=user.id,
        purpose=purpose,
        code_hash=_hash_code(code),
        expires_at=now + timedelta(minutes=settings.OTP_EXPIRE_MINUTES),
    )
    db.add(otp)
    db.commit()

    sender = send_verify_email_otp if purpose == OtpPurpose.verify_email else send_password_reset_otp
    background_tasks.add_task(sender, user.email, code)

    return settings.OTP_RESEND_COOLDOWN_SECONDS


def verify_code(db: Session, user: User, purpose: OtpPurpose, code: str) -> None:
    """Validates `code` against the latest unconsumed OTP for the user, raising HTTP 400
    on any failure. Marks the OTP consumed on success.
    """
    otp = _latest_for(db, user.id, purpose)
    if otp is None or otp.consumed_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No active code. Please request a new one.",
        )
    if _utcnow() > _aware(otp.expires_at):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This code has expired. Please request a new one.",
        )
    if otp.attempts >= settings.OTP_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Too many incorrect attempts. Please request a new code.",
        )
    if not hmac.compare_digest(otp.code_hash, _hash_code(code)):
        otp.attempts += 1
        db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Incorrect code.")

    otp.consumed_at = _utcnow()
    db.commit()
