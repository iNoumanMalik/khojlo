from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration, loaded from environment / .env file."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    PROJECT_NAME: str = "Khojlo API"
    API_V1_PREFIX: str = "/api/v1"

    DATABASE_URL: str = "postgresql+psycopg2://khojlo:khojlo@localhost:5432/khojlo"

    SECRET_KEY: str = "change-me-to-a-long-random-string"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 14

    BACKEND_CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080,http://localhost:5000"

    # ── Google Sign-In ──
    # The "Web client" OAuth client ID (client_type 3) from google-services.json.
    # Used as the expected audience when verifying Google ID tokens from the app.
    GOOGLE_WEB_CLIENT_ID: str | None = None

    # ── SMTP / email (future — optional) ──
    SMTP_HOST: str | None = None
    SMTP_PORT: int = 587
    SMTP_USERNAME: str | None = None
    SMTP_PASSWORD: str | None = None
    SMTP_FROM_EMAIL: str = "no-reply@khojlo.app"
    SMTP_FROM_NAME: str = "Khojlo"
    SMTP_USE_TLS: bool = True

    # ── Firebase / FCM push (future — optional) ──
    GOOGLE_APPLICATION_CREDENTIALS: str | None = None
    FIREBASE_PROJECT_ID: str | None = None
    FIREBASE_CLIENT_EMAIL: str | None = None
    FIREBASE_PRIVATE_KEY: str | None = None

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.BACKEND_CORS_ORIGINS.split(",") if o.strip()]

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
