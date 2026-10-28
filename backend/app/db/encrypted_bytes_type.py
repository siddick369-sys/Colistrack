"""TypeDecorator SQLAlchemy pour le chiffrement transparent AES-256-GCM des octets sensibles (CNI)."""
import logging
from typing import Optional, Union
from sqlalchemy import LargeBinary
from sqlalchemy.types import TypeDecorator
from app.core.crypto import (
    BINARY_VERSION_BYTE,
    CryptographicIntegrityError,
    InvalidEnvelopeError,
    UnknownKeyIdError,
    decrypt_bytes,
    encrypt_bytes,
)
from app.core.exceptions import DecryptionError

logger = logging.getLogger("colistrack.security.encrypted_bytes_type")


class EncryptedBytes(TypeDecorator):
    """Chiffre les octets sensibles (ex: scans ou numéros de CNI binaires) en AES-256-GCM."""

    impl = LargeBinary
    cache_ok = True

    def process_bind_param(
        self,
        value: Optional[Union[bytes, bytearray, str]],
        dialect,
    ) -> Optional[bytes]:
        if value is None:
            return None

        raw_bytes: bytes
        if isinstance(value, str):
            raw_bytes = value.encode("utf-8")
        elif isinstance(value, (bytes, bytearray)):
            raw_bytes = bytes(value)
        else:
            raise TypeError("La valeur à chiffrer doit être de type bytes, bytearray ou str.")

        # Protection anti-double-chiffrement si déjà sous enveloppe binaire v1 valide
        if len(raw_bytes) >= 31 and raw_bytes[:1] == BINARY_VERSION_BYTE:
            key_id_len = raw_bytes[1]
            if len(raw_bytes) >= 2 + key_id_len + 12 + 16:
                return raw_bytes

        return encrypt_bytes(raw_bytes)

    def process_result_value(
        self,
        value: Optional[bytes],
        dialect,
    ) -> Optional[bytes]:
        if value is None:
            return None

        # Donnée historique non chiffrée
        if len(value) < 31 or value[:1] != BINARY_VERSION_BYTE:
            return value

        try:
            return decrypt_bytes(value)
        except CryptographicIntegrityError as exc:
            logger.critical(
                "Alerte d'intégrité cryptographique sur EncryptedBytes: "
                "le ciphertext a été altéré ou falsifié. Aucune donnée exposée.",
            )
            raise DecryptionError("EncryptedBytes", "CryptographicIntegrityError") from exc
        except InvalidEnvelopeError as exc:
            logger.error(
                "Alerte de format sur EncryptedBytes: enveloppe binaire tronquée ou corrompue.",
            )
            raise DecryptionError("EncryptedBytes", "InvalidEnvelopeError") from exc
        except UnknownKeyIdError as exc:
            logger.critical(
                "Alerte de clé sur EncryptedBytes: identifiant de clé inconnu.",
            )
            raise DecryptionError("EncryptedBytes", "UnknownKeyIdError") from exc
        except Exception as exc:
            logger.error(
                "Erreur inattendue lors du déchiffrement EncryptedBytes: %s",
                type(exc).__name__,
            )
            raise DecryptionError("EncryptedBytes", type(exc).__name__) from exc
