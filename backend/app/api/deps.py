from datetime import datetime, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.privacy import PRIVACY_POLICY_VERSION
from app.core.security import ACCESS_TOKEN, decode_token
from app.models.user import User, UserRole
from app.services.moderation_service import account_block

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=True)

_credentials_error = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> User:
    payload = decode_token(token)
    if payload is None or payload.get("type") != ACCESS_TOKEN:
        raise _credentials_error
    user_id = payload.get("sub")
    if user_id is None:
        raise _credentials_error
    user = db.get(User, int(user_id))
    if user is None:
        raise _credentials_error
    ensure_active(user)
    return user


def ensure_active(user: User) -> None:
    """Module 8: suspended and banned accounts can't use the API (403, with the reason)."""
    reason = account_block(user)
    if reason:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=reason,
            headers={"X-Account-Status": "blocked"},
        )


def get_current_admin(user: User = Depends(get_current_user)) -> User:
    """SEC-3: administrative functions are for administrators only."""
    if user.role != UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Admin account required"
        )
    return user


def get_current_owner(user: User = Depends(get_current_user)) -> User:
    if user.role not in (UserRole.business_owner, UserRole.admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Business owner account required",
        )
    return user


def get_optional_user(
    db: Session = Depends(get_db),
    token: str | None = Depends(OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)),
) -> User | None:
    """Resolve the current user if a valid token is supplied, else None."""
    if not token:
        return None
    payload = decode_token(token)
    if payload is None or payload.get("type") != ACCESS_TOKEN:
        return None
    user_id = payload.get("sub")
    if user_id is None:
        return None
    user = db.get(User, int(user_id))
    # A suspended account browses like a signed-out visitor.
    return user if user is not None and account_block(user) is None else None


def get_now() -> datetime:
    """The current UTC time. Tests override this dependency to freeze the clock
    (e.g. to check "open now" at a known hour)."""
    return datetime.now(timezone.utc)


def require_current_privacy_policy(version: str) -> None:
    """The app agreed to an older policy than the server's: make the user read the new one."""
    if version != PRIVACY_POLICY_VERSION:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Our privacy policy has changed. Please review it and try again.",
        )
