"""Module de sanitisation et de détection des données personnelles sensibles (PII).

Empêche la fuite ou l'injection accidentelle d'identifiants légaux
(ex: numéros de CNI, passeport, récépissé) dans les champs de texte libre
tels que les descriptions d'événements de suivi.
"""
import re
from typing import Optional

# Motifs de détection des identifiants sensibles d'identité
_CNI_PATTERNS = [
    # Numéro CNI numérique typique (au moins 8 chiffres consécutifs)
    re.compile(r"\b\d{8,15}\b"),
    # Formulations explicites avec mot-clé d'identité suivi de caractères alphanumériques
    re.compile(
        r"(?i)\b(cni|carte\s+d['’]identit[eé]|passeport|r[eé]c[eé]piss[eé])\b\s*[:\-n°#]*\s*[\w\d\-]{5,}",
    ),
    # Formulations de type "N° 12345678"
    re.compile(r"(?i)\bn°\s*\d{6,}\b"),
]


def contains_pii_identifier(text: str) -> bool:
    """Vérifie si un texte contient un identifiant de pièce d'identité ou numéro légal."""
    if not text:
        return False
    for pattern in _CNI_PATTERNS:
        if pattern.search(text):
            return True
    return False


def sanitize_event_description(description: str) -> str:
    """Valide qu'une description d'événement de suivi ne contient aucun numéro de CNI.

    Retourne la description d'origine si conforme, ou lève ValueError
    avec un message générique sans divulgation d'informations.
    """
    if not description:
        return ""
    if contains_pii_identifier(description):
        raise ValueError(
            "La description de l'événement ne doit pas contenir de numéro de pièce d'identité "
            "ou d'identifiant personnel. Utilisez une mention générique comme 'Vérification d'identité effectuée'."
        )
    return description
