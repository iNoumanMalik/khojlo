from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration, loaded from environment / .env file."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    PROJECT_NAME: str = "Khojlo API"
    API_V1_PREFIX: str = "/api/v1"

    DATABASE_URL: str = "postgresql+psycopg2://khojlo:khojlo@localhost:5432/khojlo"
    # Log a warning at startup when the database is missing migrations (`alembic upgrade head`).
    SCHEMA_CHECK_ON_STARTUP: bool = True

    SECRET_KEY: str = "change-me-to-a-long-random-string"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 14

    BACKEND_CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080,http://localhost:5000"

    # ── Google Sign-In ──
    # The "Web client" OAuth client ID (client_type 3) from google-services.json.
    # Used as the expected audience when verifying Google ID tokens from the app.
    GOOGLE_WEB_CLIENT_ID: str | None = None

    # ── SMTP / email ──
    SMTP_HOST: str | None = None
    SMTP_PORT: int = 587
    SMTP_USERNAME: str | None = None
    SMTP_PASSWORD: str | None = None
    SMTP_FROM_EMAIL: str = "no-reply@khojlo.app"
    SMTP_FROM_NAME: str = "Khojlo"
    SMTP_USE_TLS: bool = True

    # ── Email OTP (verification + password reset) ──
    OTP_EXPIRE_MINUTES: int = 10
    OTP_RESEND_COOLDOWN_SECONDS: int = 45
    OTP_MAX_PER_DAY: int = 5
    OTP_MAX_ATTEMPTS: int = 5
    PASSWORD_RESET_TOKEN_EXPIRE_MINUTES: int = 10

    # ── Search, filtering & comparison (Module 4) ──
    # Businesses are local, so "open now" is evaluated in their timezone, not the server's (UTC).
    BUSINESS_TIMEZONE: str = "Asia/Karachi"
    # A business counts as "new" (badge + ranking tie-break) for this many days after it joins.
    NEW_BUSINESS_DAYS: int = 30
    # Upper bound for the distance filter.
    SEARCH_MAX_RADIUS_KM: float = 50.0

    # ── Maps & location (Module 6) ──
    # Server-only Google key with just the Geocoding API enabled. Without it, address
    # lookup is switched off and the app falls back to typed addresses.
    GOOGLE_MAPS_SERVER_KEY: str | None = None
    # Bias results towards this country (ccTLD) and return text in this language.
    GEOCODING_REGION: str = "pk"
    GEOCODING_LANGUAGE: str = "en"

    # ── Firebase / FCM push (future — optional) ──
    GOOGLE_APPLICATION_CREDENTIALS: str | None = None
    FIREBASE_PROJECT_ID: str | None = None
    FIREBASE_CLIENT_EMAIL: str | None = None
    FIREBASE_PRIVATE_KEY: str | None = None

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.BACKEND_CORS_ORIGINS.split(",") if o.strip()]

    @property
    def geocoding_enabled(self) -> bool:
        return bool(self.GOOGLE_MAPS_SERVER_KEY)

    @property
    def email_enabled(self) -> bool:
        return bool(self.SMTP_HOST and self.SMTP_USERNAME and self.SMTP_PASSWORD)

    @property
    def firebase_enabled(self) -> bool:
        return bool(
            self.GOOGLE_APPLICATION_CREDENTIALS
            or (self.FIREBASE_PROJECT_ID and self.FIREBASE_CLIENT_EMAIL and self.FIREBASE_PRIVATE_KEY)
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
