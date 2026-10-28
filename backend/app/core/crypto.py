"""Service de chiffrement symétrique authentifié AES-256-GCM avec gestion du cycle de vie des clés.

Fournit le chiffrement/déchiffrement de données sensibles (ex: CNI) sous enveloppe
versionnée et non ambiguë, avec prise en charge de la rotation de clés et de la vérification d'intégrité.
"""
import base64
from enum import Enum
import json
import os
import re
from typing import Dict, Optional, Union
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from app.core.config import settings

# Constantes du protocole d'enveloppe cryptographique
BINARY_VERSION_BYTE = b"\x01"
TEXT_VERSION_PREFIX = "v1"
NONCE_LENGTH_BYTES = 12
GCM_TAG_LENGTH_BYTES = 16
KEY_ID_REGEX = re.compile(r"^[a-zA-Z0-9_\-]{1,32}$")


class CryptographicError(Exception):
    """Exception de base pour les erreurs du service cryptographique."""
    pass


class CryptographicIntegrityError(CryptographicError):
    """Levée en cas d'altération du texte chiffré, du nonce ou du tag d'authentification."""
    pass


class UnknownKeyIdError(CryptographicError):
    """Levée lorsqu'un identifiant de clé n'est pas présent dans le registre de clés autorisées."""
    pass


class InvalidEnvelopeError(CryptographicError):
    """Levée lorsque le format ou la structure de l'enveloppe chiffrée est invalide ou tronquée."""
    pass


def _load_key_registry() -> Dict[str, bytes]:
    """Charge et valide le registre des clés cryptographiques (primaire + archives)."""
    registry: Dict[str, bytes] = {}

    # 1. Clé primaire active
    primary_id = settings.DATA_ENCRYPTION_PRIMARY_KEY_ID.strip()
    if not KEY_ID_REGEX.match(primary_id):
        raise ValueError(f"Identifiant de clé primaire invalide : {primary_id}")

    primary_hex = settings.DATA_ENCRYPTION_KEY.strip()
    try:
        primary_bytes = bytes.fromhex(primary_hex)
    except ValueError as e:
        raise ValueError(f"Format hexadécimal invalide pour la clé primaire {primary_id}") from e

    if len(primary_bytes) != 32:
        raise ValueError(f"La clé primaire {primary_id} doit faire exactement 32 octets (AES-256).")

    registry[primary_id] = primary_bytes

    # 2. Clés archivées pour déchiffrement lors des rotations
    if settings.DATA_ENCRYPTION_OLD_KEYS:
        try:
            old_keys_dict = json.loads(settings.DATA_ENCRYPTION_OLD_KEYS)
            if isinstance(old_keys_dict, dict):
                for kid, khex in old_keys_dict.items():
                    kid_clean = str(kid).strip()
                    if not KEY_ID_REGEX.match(kid_clean):
                        continue
                    try:
                        kbytes = bytes.fromhex(str(khex).strip())
                        if len(kbytes) == 32:
                            registry[kid_clean] = kbytes
                    except Exception:
                        continue
        except Exception:
            pass

    return registry


def _get_key_bytes(key_id: str) -> bytes:
    """Récupère les 32 octets de la clé correspondant à l'identifiant demandé."""
    registry = _load_key_registry()
    if key_id not in registry:
        raise UnknownKeyIdError(f"Identifiant de clé cryptographique inconnu : {key_id}")
    return registry[key_id]


def encrypt_bytes(plaintext: bytes, key_id: Optional[str] = None) -> bytes:
    """Chiffre des octets en AES-256-GCM et retourne une enveloppe binaire versionnée non ambiguë.
    
    Structure de l'enveloppe binaire :
    [1 octet version 0x01][1 octet longueur key_id][key_id ASCII][12 octets nonce][ciphertext + tag 16 octets]
    """
    if not isinstance(plaintext, (bytes, bytearray)):
        raise TypeError("Le texte en clair doit être de type bytes ou bytearray.")

    active_key_id = key_id or settings.DATA_ENCRYPTION_PRIMARY_KEY_ID.strip()
    key_bytes = _get_key_bytes(active_key_id)

    key_id_bytes = active_key_id.encode("ascii")
    if len(key_id_bytes) > 255:
        raise ValueError("L'identifiant de clé dépasse la taille maximale autorisée (255 octets).")

    nonce = os.urandom(NONCE_LENGTH_BYTES)
    aesgcm = AESGCM(key_bytes)

    # Données associées authentifiées (AAD) liant la version et l'identifiant de clé
    aad = BINARY_VERSION_BYTE + key_id_bytes
    ciphertext_with_tag = aesgcm.encrypt(nonce, bytes(plaintext), aad)

    envelope = (
        BINARY_VERSION_BYTE
        + bytes([len(key_id_bytes)])
        + key_id_bytes
        + nonce
        + ciphertext_with_tag
    )
    return envelope


def decrypt_bytes(envelope: bytes) -> bytes:
    """Valide l'intégrité et déchiffre une enveloppe binaire AES-256-GCM."""
    if not isinstance(envelope, (bytes, bytearray)):
        raise TypeError("L'enveloppe chiffrée doit être de type bytes ou bytearray.")

    # Taille minimale = 1 (version) + 1 (len_kid) + 1 (min kid) + 12 (nonce) + 16 (tag GCM) = 31 octets
    if len(envelope) < 31:
        raise InvalidEnvelopeError("Enveloppe binaire tronquée ou de taille insuffisante.")

    version_byte = envelope[:1]
    if version_byte != BINARY_VERSION_BYTE:
        raise InvalidEnvelopeError(f"Version d'enveloppe binaire non supportée : {version_byte!r}")

    key_id_len = envelope[1]
    offset = 2
    if len(envelope) < offset + key_id_len + NONCE_LENGTH_BYTES + GCM_TAG_LENGTH_BYTES:
        raise InvalidEnvelopeError("Enveloppe binaire corrompue (taille incohérente avec key_id).")

    try:
        key_id = envelope[offset : offset + key_id_len].decode("ascii")
    except UnicodeDecodeError as e:
        raise InvalidEnvelopeError("Identifiant de clé non décodable en ASCII dans l'enveloppe.") from e

    offset += key_id_len
    nonce = envelope[offset : offset + NONCE_LENGTH_BYTES]
    offset += NONCE_LENGTH_BYTES
    ciphertext_with_tag = envelope[offset:]

    key_bytes = _get_key_bytes(key_id)
    aesgcm = AESGCM(key_bytes)
    aad = BINARY_VERSION_BYTE + key_id.encode("ascii")

    try:
        plaintext = aesgcm.decrypt(nonce, ciphertext_with_tag, aad)
        return plaintext
    except InvalidTag as e:
        raise CryptographicIntegrityError(
            "Échec de validation de l'intégrité cryptographique (altération du ciphertext, du tag ou du nonce)."
        ) from e


def encrypt_str(plaintext: str, key_id: Optional[str] = None) -> str:
    """Chiffre une chaîne de caractères et retourne une enveloppe texte versionnée :
    v1$key_id$nonce_b64$ciphertext_tag_b64
    """
    if not isinstance(plaintext, str):
        raise TypeError("Le texte en clair doit être de type str.")

    active_key_id = key_id or settings.DATA_ENCRYPTION_PRIMARY_KEY_ID.strip()
    key_bytes = _get_key_bytes(active_key_id)

    nonce = os.urandom(NONCE_LENGTH_BYTES)
    aesgcm = AESGCM(key_bytes)

    aad = f"{TEXT_VERSION_PREFIX}${active_key_id}".encode("ascii")
    ciphertext_with_tag = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), aad)

    nonce_b64 = base64.urlsafe_b64encode(nonce).decode("ascii")
    ciphertext_b64 = base64.urlsafe_b64encode(ciphertext_with_tag).decode("ascii")

    return f"{TEXT_VERSION_PREFIX}${active_key_id}${nonce_b64}${ciphertext_b64}"


def decrypt_str(envelope_str: str) -> str:
    """Valide l'intégrité et déchiffre une enveloppe texte formatée."""
    if not isinstance(envelope_str, str):
        raise TypeError("L'enveloppe chiffrée doit être une chaîne de caractères.")

    parts = envelope_str.split("$")
    if len(parts) != 4:
        raise InvalidEnvelopeError("Format d'enveloppe texte invalide (4 segments séparés par '$' requis).")

    version, key_id, nonce_b64, ciphertext_b64 = parts
    if version != TEXT_VERSION_PREFIX:
        raise InvalidEnvelopeError(f"Version d'enveloppe texte non supportée : {version}")

    # Vérification préalable de l'identifiant de clé dans le registre
    key_bytes = _get_key_bytes(key_id)

    try:
        # Ajout automatique du padding si nécessaire
        padded_nonce = nonce_b64 + "=" * (-len(nonce_b64) % 4)
        padded_cipher = ciphertext_b64 + "=" * (-len(ciphertext_b64) % 4)
        nonce = base64.urlsafe_b64decode(padded_nonce)
        ciphertext_with_tag = base64.urlsafe_b64decode(padded_cipher)
    except Exception as e:
        raise InvalidEnvelopeError("Encodage Base64 invalide dans l'enveloppe texte.") from e

    if len(nonce) != NONCE_LENGTH_BYTES:
        raise InvalidEnvelopeError(f"Longueur de nonce invalide : attendu {NONCE_LENGTH_BYTES}, reçu {len(nonce)}.")

    if len(ciphertext_with_tag) < GCM_TAG_LENGTH_BYTES:
        raise InvalidEnvelopeError("Ciphertext avec tag tronqué.")

    key_bytes = _get_key_bytes(key_id)
    aesgcm = AESGCM(key_bytes)
    aad = f"{TEXT_VERSION_PREFIX}${key_id}".encode("ascii")

    try:
        plaintext_bytes = aesgcm.decrypt(nonce, ciphertext_with_tag, aad)
        return plaintext_bytes.decode("utf-8")
    except InvalidTag as e:
        raise CryptographicIntegrityError(
            "Échec de validation de l'intégrité cryptographique (altération du texte chiffré ou du tag)."
        ) from e


def rotate_encrypted_bytes(envelope: bytes, new_key_id: str) -> bytes:
    """Déchiffre une enveloppe binaire avec son ancienne clé et la rechiffre avec une nouvelle clé."""
    plaintext = decrypt_bytes(envelope)
    return encrypt_bytes(plaintext, key_id=new_key_id)


def rotate_encrypted_str(envelope_str: str, new_key_id: str) -> str:
    """Déchiffre une enveloppe texte avec son ancienne clé et la rechiffre avec une nouvelle clé."""
    plaintext = decrypt_str(envelope_str)
    return encrypt_str(plaintext, key_id=new_key_id)


class ValueClassification(Enum):
    """Classification sans ambiguïté des valeurs PII en 3 états stricts."""

    NULL = "NULL"
    PLAINTEXT = "PLAINTEXT"
    VALID_CIPHERTEXT = "VALID_CIPHERTEXT"
    INVALID_OR_AMBIGUOUS = "INVALID_OR_AMBIGUOUS"


def classify_text_value(value: Optional[str]) -> ValueClassification:
    """Classifie sans ambiguïté une valeur textuelle PII.

    - NULL : Valeur absente (None).
    - PLAINTEXT : Valeur historique en clair ne commençant pas par le préfixe candidat 'v1$'.
    - VALID_CIPHERTEXT : Enveloppe candidate 'v1$' authentifiée avec succès auprès des clés du registre.
    - INVALID_OR_AMBIGUOUS : Enveloppe candidate 'v1$' qui ne peut être authentifiée (altération,
      clé inconnue, format corrompu, ou chaîne historique ambiguë).
    """
    if value is None:
        return ValueClassification.NULL

    val_str = str(value)
    if not val_str.startswith(f"{TEXT_VERSION_PREFIX}$"):
        return ValueClassification.PLAINTEXT

    try:
        decrypt_str(val_str)
        return ValueClassification.VALID_CIPHERTEXT
    except (CryptographicIntegrityError, UnknownKeyIdError, InvalidEnvelopeError):
        return ValueClassification.INVALID_OR_AMBIGUOUS
    except Exception:
        return ValueClassification.INVALID_OR_AMBIGUOUS


def classify_bytes_value(value: Optional[Union[bytes, bytearray, str]]) -> ValueClassification:
    """Classifie sans ambiguïté une valeur binaire PII (CNI).

    - NULL : Valeur absente (None).
    - PLAINTEXT : Octets historiques en clair ne débutant pas par l'octet de version binaire 0x01.
    - VALID_CIPHERTEXT : Enveloppe candidate 0x01 authentifiée avec succès auprès des clés du registre.
    - INVALID_OR_AMBIGUOUS : Enveloppe candidate 0x01 qui ne peut être authentifiée.
    """
    if value is None:
        return ValueClassification.NULL

    raw: bytes
    if isinstance(value, str):
        raw = value.encode("utf-8")
    elif isinstance(value, (bytes, bytearray)):
        raw = bytes(value)
    else:
        return ValueClassification.INVALID_OR_AMBIGUOUS

    if len(raw) < 1 or raw[:1] != BINARY_VERSION_BYTE:
        return ValueClassification.PLAINTEXT

    try:
        decrypt_bytes(raw)
        return ValueClassification.VALID_CIPHERTEXT
    except (CryptographicIntegrityError, UnknownKeyIdError, InvalidEnvelopeError):
        return ValueClassification.INVALID_OR_AMBIGUOUS
    except Exception:
        return ValueClassification.INVALID_OR_AMBIGUOUS
