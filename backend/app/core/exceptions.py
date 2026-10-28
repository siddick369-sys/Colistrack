"""Exceptions spécifiques à la sécurité et à la cryptographie dans ColisTrack."""


class DecryptionError(Exception):
    """Levée lors d'un échec de déchiffrement d'une colonne sensible.

    Garantit la confidentialité : ne contient jamais le texte en clair,
    le texte chiffré, le nonce ou les clés.
    """

    def __init__(self, column_name: str, error_type: str):
        self.column_name = column_name
        self.error_type = error_type
        super().__init__(
            f"Échec de déchiffrement pour la colonne '{column_name}' (motif: {error_type})"
        )
