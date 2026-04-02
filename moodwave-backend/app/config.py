from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Database
    DATABASE_URL: str
    DB_PASSWORD: str = "password"

    # Redis
    REDIS_URL: str = "redis://localhost:6379"

    # JWT
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Spotify
    SPOTIFY_CLIENT_ID: str = ""
    SPOTIFY_CLIENT_SECRET: str = ""

    # OpenWeatherMap
    OPENWEATHER_API_KEY: str = ""

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "./firebase-credentials.json"
    FIREBASE_DATABASE_URL: str = ""

    # Mail
    MAIL_USERNAME: str = ""
    MAIL_PASSWORD: str = ""
    MAIL_FROM: str = ""
    MAIL_PORT: int = 587
    MAIL_SERVER: str = "smtp.gmail.com"

    # OAuth
    GOOGLE_CLIENT_ID: str = ""

    # App
    APP_ENV: str = "development"

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def normalize_database_url(cls, value: str) -> str:
        if isinstance(value, str) and value.startswith("DATABASE_URL="):
            value = value.split("=", 1)[1]
        if isinstance(value, str):
            if value.startswith("postgresql://") and "+asyncpg" not in value:
                return value.replace("postgresql://", "postgresql+asyncpg://", 1)
            if value.startswith("postgres://") and "+asyncpg" not in value:
                return value.replace("postgres://", "postgresql+asyncpg://", 1)
        return value


settings = Settings()
