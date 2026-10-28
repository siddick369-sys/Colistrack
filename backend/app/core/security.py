"""Fonctions de sécurité cryptographique : hachage de mot de passe et gestion des JWT."""
import base64
from datetime import datetime, timedelta, timezone
import hashlib
from typing import Any, Dict, Optional
import bcrypt
from fastapi import HTTPException, status
import jwt
from app.core.config import settings

# Préfixe officiel du format moderne de mot de passe (sans troncature, SHA-256 + Bcrypt 12 rounds)
MODERN_HASH_PREFIX = "$v1$sha256$"

# Empreinte bcrypt réelle valide (12 rounds) pour neutraliser les attaques temporelles au login
DUMMY_BCRYPT_HASH = "$2b$12$CcUIFwEV2l1sU2AB9ZlafOBnwB0vApYjsKoNWkvfyuMWNY7lhWyei"


def get_password_hash(password: str) -> str:
    """Hache un mot de passe moderne selon le protocole sécurisé v1 (SHA-256 + Bcrypt 12 rounds)."""
    pwd_bytes = password.encode("utf-8")
    if len(pwd_bytes) == 0:
        raise ValueError("Le mot de passe ne peut pas être vide.")
    if len(pwd_bytes) > 128:
        raise ValueError("Le mot de passe ne doit pas dépasser 128 octets UTF-8.")

    # Prétraitement SHA-256 base64 (44 caractères), strictement inférieur à la limite de 72 octets de bcrypt
    sha256_b64 = base64.b64encode(hashlib.sha256(pwd_bytes).digest())
    salt = bcrypt.gensalt(rounds=12)
    bcrypt_hash = bcrypt.hashpw(sha256_b64, salt).decode("utf-8")
    return f"{MODERN_HASH_PREFIX}{bcrypt_hash}"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Vérifie un mot de passe en temps constant, avec prise en charge rétrocompatible du format historique."""
    try:
        pwd_bytes = plain_password.encode("utf-8")
        if hashed_password.startswith(MODERN_HASH_PREFIX):
            if len(pwd_bytes) > 128:
                return False
            bcrypt_part = hashed_password[len(MODERN_HASH_PREFIX):]
            sha256_b64 = base64.b64encode(hashlib.sha256(pwd_bytes).digest())
            return bcrypt.checkpw(sha256_b64, bcrypt_part.encode("utf-8"))
        else:
            # Empreinte historique : conservation temporaire du comportement bcrypt brut limité à 72 octets
            legacy_bytes = pwd_bytes[:72]
            return bcrypt.checkpw(legacy_bytes, hashed_password.encode("utf-8"))
    except Exception:
        return False


def is_legacy_password_hash(hashed_password: str) -> bool:
    """Indique si une empreinte de mot de passe utilise l'ancien format bcrypt non versionné."""
    return not hashed_password.startswith(MODERN_HASH_PREFIX)


def verify_dummy_password(plain_password: str) -> None:
    """Exécute une vérification cryptographique réelle (~200-250ms) pour neutraliser les timing attacks."""
    try:
        pwd_bytes = plain_password.encode("utf-8")[:128]
        sha256_b64 = base64.b64encode(hashlib.sha256(pwd_bytes).digest())
        bcrypt.checkpw(sha256_b64, DUMMY_BCRYPT_HASH.encode("utf-8"))
    except Exception:
        pass


def create_access_token(
    subject: str,
    user_id: str,
    token_version: int = 1,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Génère un jeton JWT d'accès signé selon l'algorithme serveur configuré."""
    now = datetime.now(timezone.utc)
    if expires_delta is not None:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    payload: Dict[str, Any] = {
        "sub": subject,
        "uid": str(user_id),
        "ver": token_version,
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
        "iat": now,
        "exp": expire,
        "type": "access",
    }

    # Signature cryptographique avec clé serveur et algorithme fixé (ex: HS256)
    encoded_jwt = jwt.encode(
        payload,
        settings.effective_jwt_secret_key,
        algorithm=settings.JWT_ALGORITHM,
    )
    return encoded_jwt


def decode_access_token(token: str) -> Dict[str, Any]:
    """Décode et valide rigoureusement un jeton JWT (signature, expiration, audience, émetteur)."""
    try:
        payload = jwt.decode(
            token,
            settings.effective_jwt_secret_key,
            algorithms=[settings.JWT_ALGORITHM],  # Rejet strict de 'none' ou d'algorithmes non autorisés
            issuer=settings.JWT_ISSUER,
            audience=settings.JWT_AUDIENCE,
            options={
                "require": ["exp", "iat", "sub", "uid", "iss", "aud"],
                "verify_exp": True,
                "verify_iat": True,
                "verify_iss": True,
                "verify_aud": True,
            },
        )
        if payload.get("type") != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Type de jeton invalide (accès requis)",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Le jeton d'authentification a expiré",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Jeton d'authentification invalide ou altéré",
            headers={"WWW-Authenticate": "Bearer"},
        )
