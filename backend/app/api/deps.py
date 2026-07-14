from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import ACCESS_TOKEN, decode_token
from app.models.user import User, UserRole

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
    return db.get(User, int(user_id))
