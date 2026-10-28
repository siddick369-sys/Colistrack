"""Ajout de la colonne token_version sur la table users pour révocation immédiate

Revision ID: 002_add_user_token_version
Revises: 001_initial_c2_3_schema
Create Date: 2026-10-26 10:45:00.000000 UTC

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "002_add_user_token_version"
down_revision: Union[str, None] = "001_initial_c2_3_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("token_version", sa.Integer(), nullable=False, server_default="1"),
    )


def downgrade() -> None:
    op.drop_column("users", "token_version")
