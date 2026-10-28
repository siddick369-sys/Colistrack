"""TypeDecorator SQLAlchemy pour le chiffrement transparent AES-256-GCM des chaînes sensibles."""
import logging
from typing import Optional
from sqlalchemy import String
from sqlalchemy.types import TypeDecorator
from app.core.crypto import (
    CryptographicIntegrityError,
    InvalidEnvelopeError,
    UnknownKeyIdError,
    decrypt_str,
    encrypt_str,
)
from app.core.exceptions import DecryptionError

logger = logging.getLogger("colistrack.security.encrypted_type")
ENVELOPE_PREFIX = "v1$"


class EncryptedString(TypeDecorator):
    """Chiffre les chaînes sensibles en AES-256-GCM avant persistance et les déchiffre à la lecture.

    Règles de sécurité :
    1. process_bind_param : Chiffre toute chaîne entrante sous enveloppe v1$key_id$nonce$tag_cipher.
       Évite le double-chiffrement si la valeur est déjà une enveloppe valide à 4 segments.
    2. process_result_value : Déchiffre l'enveloppe à la lecture.
       - Si la valeur ne débute pas par 'v1$', elle est traitée comme donnée historique en clair
         (rétrocompatibilité de lecture).
       - En cas d'échec cryptographique (altération, mauvaise clé, corruption), lève systématiquement
         une exception contrôlée DecryptionError sans jamais retourner silencieusement None ou le ciphertext.
    """

    impl = String(512)
    cache_ok = True

    def process_bind_param(self, value: Optional[str], dialect) -> Optional[str]:
        if value is None:
            return None

        val_str = str(value)
        # Protection anti-double-chiffrement si la valeur est déjà une enveloppe valide
        if val_str.startswith(ENVELOPE_PREFIX):
            parts = val_str.split("$")
            if len(parts) == 4 and parts[0] == "v1":
                return val_str

        return encrypt_str(val_str)

    def process_result_value(self, value: Optional[str], dialect) -> Optional[str]:
        if value is None:
            return None

        # Donnée historique non chiffrée : rétrocompatibilité immédiate
        if not value.startswith(ENVELOPE_PREFIX):
            return value

        try:
            return decrypt_str(value)
        except CryptographicIntegrityError as exc:
            logger.critical(
                "Alerte d'intégrité cryptographique sur EncryptedString: "
                "le ciphertext a été altéré ou falsifié. Aucune donnée exposée.",
            )
            raise DecryptionError("EncryptedString", "CryptographicIntegrityError") from exc
        except InvalidEnvelopeError as exc:
            logger.error(
                "Alerte de format sur EncryptedString: enveloppe corrompue ou tronquée.",
            )
            raise DecryptionError("EncryptedString", "InvalidEnvelopeError") from exc
        except UnknownKeyIdError as exc:
            logger.critical(
                "Alerte de clé sur EncryptedString: identifiant de clé inconnu dans le registre actif.",
            )
            raise DecryptionError("EncryptedString", "UnknownKeyIdError") from exc
        except Exception as exc:
            logger.error(
                "Erreur inattendue lors du déchiffrement EncryptedString: %s",
                type(exc).__name__,
            )
            raise DecryptionError("EncryptedString", type(exc).__name__) from exc
