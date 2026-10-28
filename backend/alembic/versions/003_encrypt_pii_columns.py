"""Migration structurelle C2.5 : élargissement des colonnes PII et ajout du flag is_pii_encrypted

Revision ID: 003_encrypt_pii_columns
Revises: 002_add_user_token_version
Create Date: 2026-10-26 12:00:00.000000 UTC

CE QUE FAIT CETTE MIGRATION :
- Élargit les colonnes PII de String(N) à String(512) pour accueillir les enveloppes AES-256-GCM.
- Ajoute la colonne is_pii_encrypted (Boolean, server_default=false) pour le suivi de migration des données.

CE QU'ELLE NE FAIT PAS :
- Elle n'accède à aucune clé secrète.
- Elle ne chiffre pas les données en place (confié au script séparé scripts/migrate_pii_data.py).

DOWNGRADE : Délibérément bloqué avec levée d'exception pour empêcher toute troncature
ou corruption irréversible des données chiffrées.
"""
from typing import Sequence, Union
from alembic import op
from alembic.util import CommandError
import sqlalchemy as sa

revision: str = "003_encrypt_pii_columns"
down_revision: Union[str, None] = "002_add_user_token_version"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Table parcels
    with op.batch_alter_table("parcels", schema=None) as batch_op:
        batch_op.alter_column(
            "sender_name",
            existing_type=sa.String(length=150),
            type_=sa.String(length=512),
            nullable=False,
        )
        batch_op.alter_column(
            "sender_phone",
            existing_type=sa.String(length=30),
            type_=sa.String(length=512),
            nullable=False,
        )
        batch_op.alter_column(
            "recipient_name",
            existing_type=sa.String(length=150),
            type_=sa.String(length=512),
            nullable=False,
        )
        batch_op.alter_column(
            "recipient_phone",
            existing_type=sa.String(length=30),
            type_=sa.String(length=512),
            nullable=False,
        )
        batch_op.add_column(
            sa.Column(
                "is_pii_encrypted",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            )
        )

    # 2. Table users
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.alter_column(
            "full_name",
            existing_type=sa.String(length=150),
            type_=sa.String(length=512),
            nullable=False,
        )
        batch_op.alter_column(
            "phone",
            existing_type=sa.String(length=30),
            type_=sa.String(length=512),
            nullable=True,
        )
        batch_op.add_column(
            sa.Column(
                "is_pii_encrypted",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            )
        )

    # 3. Table payments
    with op.batch_alter_table("payments", schema=None) as batch_op:
        batch_op.alter_column(
            "customer_phone",
            existing_type=sa.String(length=30),
            type_=sa.String(length=512),
            nullable=False,
        )
        batch_op.add_column(
            sa.Column(
                "is_pii_encrypted",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            )
        )


def downgrade() -> None:
    """Retour arrière C2.5 — BLOQUÉ DÉLIBÉRÉMENT.

    Pourquoi : Revenir à String(30) ou String(150) tronquerait silencieusement
    les enveloppes cryptographiques de 245+ caractères, causant une perte irrémédiable.
    La restauration doit se faire via restauration de sauvegarde.
    """
    raise CommandError(
        "Downgrade C2.5 bloqué : le retour arrière exige une restauration de sauvegarde "
        "pour éviter toute troncature irréversible de colonnes chiffrées."
    )
