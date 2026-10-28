import json
from typing import Literal
from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuration centralisée et validée de l'application ColisTrack Cameroun V2."""

    ENVIRONMENT: Literal["development", "testing", "production"] = Field(
        default="development",
        description="Environnement d'exécution de l'application",
    )
    APP_NAME: str = Field(
        default="ColisTrack Cameroun API",
        description="Nom officiel du service",
    )
    APP_VERSION: str = Field(
        default="2.0.0",
        description="Version sémantique du backend",
    )
    PORT: int = Field(
        default=8000,
        ge=1024,
        le=65535,
        description="Port d'écoute interne du processus FastAPI",
    )
    ALLOWED_ORIGINS: list[str] = Field(
        default=[
            "http://localhost:3000",
            "http://127.0.0.1:3000",
            "http://localhost:8001",
        ],
        description="Origines CORS autorisées (strictes, sans wildcard en production)",
    )
    SECRET_KEY: str = Field(
        default="dev-insecure-secret-key-change-in-production-min32chars!",
        min_length=16,
        description="Clé secrète serveur pour la signature interne",
    )
    JWT_SECRET_KEY: str | None = Field(
        default=None,
        description="Clé secrète pour signature JWT (fallback sur SECRET_KEY si non défini)",
    )
    JWT_ALGORITHM: str = Field(
        default="HS256",
        description="Algorithme cryptographique fixé côté serveur pour JWT",
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(
        default=30,
        ge=1,
        le=1440,
        description="Durée de vie du jeton JWT d'accès en minutes",
    )
    JWT_ISSUER: str = Field(
        default="colistrack-api",
        description="Revendication 'iss' (émetteur) du jeton",
    )
    JWT_AUDIENCE: str = Field(
        default="colistrack-client",
        description="Revendication 'aud' (audience) du jeton",
    )
    DATABASE_URL: str = Field(
        default="postgresql+asyncpg://colistrack_user:colistrack_dev_password@localhost:5433/colistrack_db",
        description="URL de connexion asynchrone PostgreSQL (asyncpg)",
    )
    SYNC_DATABASE_URL: str = Field(
        default="postgresql+psycopg2://colistrack_user:colistrack_dev_password@localhost:5433/colistrack_db",
        description="URL de connexion synchrone PostgreSQL pour Alembic (psycopg2)",
    )

    # Configuration du chiffrement symétrique des données sensibles (AES-256-GCM)
    DATA_ENCRYPTION_PRIMARY_KEY_ID: str = Field(
        default="k1",
        description="Identifiant de la clé primaire de chiffrement",
    )
    DATA_ENCRYPTION_KEY: str = Field(
        default="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        description="Clé primaire AES-256 (64 caractères hexadécimaux décodés en 32 octets)",
    )
    DATA_ENCRYPTION_OLD_KEYS: str = Field(
        default="{}",
        description="Dictionnaire JSON d'anciennes clés archivées pour rotation {key_id: key_hex}",
    )

    # Configuration du Rate-Limiting par Endpoint
    RATE_LIMITING_ENABLED: bool = Field(
        default=True,
        description="Active ou désactive la limitation de requêtes",
    )
    REDIS_URL: str | None = Field(
        default=None,
        description="URL de connexion Redis pour le limiteur distribué (ex: redis://localhost:6379/0)",
    )
    TRUSTED_PROXIES: list[str] = Field(
        default=["127.0.0.1", "::1"],
        description="Liste des adresses IP des proxys de confiance certifiés pour X-Forwarded-For",
    )
    RATE_LIMIT_LOGIN: int = Field(
        default=10,
        ge=1,
        description="Quota de requêtes par minute pour /api/v1/auth/login",
    )
    RATE_LIMIT_CHANGE_PASSWORD: int = Field(
        default=10,
        ge=1,
        description="Quota de requêtes par minute pour /api/v1/auth/change-password",
    )
    RATE_LIMIT_PUBLIC: int = Field(
        default=60,
        ge=1,
        description="Quota de requêtes par minute pour les endpoints publics de consultation",
    )
    RATE_LIMIT_AUTH_READ: int = Field(
        default=60,
        ge=1,
        description="Quota de requêtes par minute pour la consultation authentifiée standard",
    )
    RATE_LIMIT_AGENCY_CONTEXT: int = Field(
        default=20,
        ge=1,
        description="Quota de requêtes par minute pour l'accès aux contextes d'agence",
    )
    RATE_LIMIT_ADMIN: int = Field(
        default=20,
        ge=1,
        description="Quota de requêtes par minute pour les opérations administratives",
    )

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def parse_allowed_origins(cls, value: object) -> list[str]:
        if isinstance(value, str):
            value = value.strip()
            if value.startswith("[") and value.endswith("]"):
                try:
                    parsed = json.loads(value)
                    if isinstance(parsed, list):
                        return [str(v).strip() for v in parsed if str(v).strip()]
                except Exception:
                    pass
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        if isinstance(value, list):
            return [str(v).strip() for v in value if str(v).strip()]
        raise ValueError("ALLOWED_ORIGINS doit être une liste ou une chaîne JSON/séparée par des virgules.")

    @model_validator(mode="after")
    def validate_production_security(self) -> "Settings":
        if self.ENVIRONMENT == "production":
            for origin in self.ALLOWED_ORIGINS:
                if origin == "*":
                    raise ValueError(
                        "Le wildcard '*' est formellement interdit pour ALLOWED_ORIGINS en production."
                    )
            lower_key = self.SECRET_KEY.lower()
            if len(self.SECRET_KEY) < 32 or "insecure" in lower_key or "change" in lower_key:
                raise ValueError(
                    "SECRET_KEY insuffisante ou factice détectée en production (minimum 32 caractères requis)."
                )
            effective_jwt_key = self.effective_jwt_secret_key.lower()
            if len(self.effective_jwt_secret_key) < 32 or "insecure" in effective_jwt_key or "change" in effective_jwt_key:
                raise ValueError(
                    "JWT_SECRET_KEY insuffisante ou factice détectée en production (minimum 32 caractères requis)."
                )
            if "localhost" in self.DATABASE_URL.lower() or "dev_password" in self.DATABASE_URL:
                raise ValueError(
                    "DATABASE_URL de développement détectée en environnement de production."
                )

            # Validation de la clé de chiffrement des données (AES-256-GCM)
            enc_key = self.DATA_ENCRYPTION_KEY.lower().strip()
            if (
                len(enc_key) != 64
                or "0123456789" in enc_key
                or "insecure" in enc_key
                or "change" in enc_key
                or "dev" in enc_key
            ):
                raise ValueError(
                    "DATA_ENCRYPTION_KEY insuffisante, factice ou de développement détectée en production (64 caractères hexadécimaux requis)."
                )
            try:
                bytes.fromhex(enc_key)
            except ValueError:
                raise ValueError("DATA_ENCRYPTION_KEY doit être une chaîne hexadécimale valide de 64 caractères.")

            if (
                enc_key == self.SECRET_KEY.lower().strip()
                or enc_key == self.effective_jwt_secret_key.lower().strip()
            ):
                raise ValueError(
                    "DATA_ENCRYPTION_KEY doit être strictement distincte de SECRET_KEY et JWT_SECRET_KEY."
                )
        return self

    @property
    def effective_jwt_secret_key(self) -> str:
        """Retourne la clé JWT spécifique ou se rabat sur la SECRET_KEY."""
        return self.JWT_SECRET_KEY if self.JWT_SECRET_KEY is not None else self.SECRET_KEY

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


# Instance singleton globale de configuration
settings = Settings()
