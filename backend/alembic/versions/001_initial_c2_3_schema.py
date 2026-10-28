"""Schéma relationnel initial C2.3 avec cloisonnement multi-agences et intégrité stricte

Revision ID: 001_initial_c2_3_schema
Revises: 
Create Date: 2026-10-25 20:30:00.000000 UTC

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "001_initial_c2_3_schema"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Table agencies
    op.create_table(
        "agencies",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=150), nullable=False),
        sa.Column("code", sa.String(length=10), nullable=False),
        sa.Column("phone", sa.String(length=30), nullable=False),
        sa.Column("city_headquarters", sa.String(length=100), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_agencies")),
    )
    op.create_index(op.f("ix_agencies_code"), "agencies", ["code"], unique=True)

    # 2. Table users
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("hashed_password", sa.String(length=255), nullable=False),
        sa.Column("full_name", sa.String(length=150), nullable=False),
        sa.Column("phone", sa.String(length=30), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_superuser", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_users")),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)

    # 3. Table agency_members
    op.create_table(
        "agency_members",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("agency_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("role", sa.String(length=30), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["agency_id"], ["agencies.id"], name=op.f("fk_agency_members_agency_id_agencies"), ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name=op.f("fk_agency_members_user_id_users"), ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_agency_members")),
        sa.UniqueConstraint("agency_id", "user_id", name="uq_agency_members_agency_user"),
        sa.CheckConstraint("role IN ('agencyManager', 'agencyAgent')", name="ck_agency_members_role"),
    )
    op.create_index(op.f("ix_agency_members_agency_id"), "agency_members", ["agency_id"], unique=False)
    op.create_index(op.f("ix_agency_members_user_id"), "agency_members", ["user_id"], unique=False)

    # 4. Table parcels
    op.create_table(
        "parcels",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("tracking_number", sa.String(length=32), nullable=False),
        sa.Column("agency_id", sa.Uuid(), nullable=False),
        sa.Column("sender_name", sa.String(length=150), nullable=False),
        sa.Column("sender_phone", sa.String(length=30), nullable=False),
        sa.Column("origin_city", sa.String(length=100), nullable=False),
        sa.Column("origin_branch", sa.String(length=100), nullable=False),
        sa.Column("recipient_name", sa.String(length=150), nullable=False),
        sa.Column("recipient_phone", sa.String(length=30), nullable=False),
        sa.Column("destination_city", sa.String(length=100), nullable=False),
        sa.Column("destination_branch", sa.String(length=100), nullable=False),
        sa.Column("pickup_counter", sa.String(length=100), server_default="Guichet 1 (Principal)", nullable=False),
        sa.Column("parcel_type", sa.String(length=100), nullable=False),
        sa.Column("weight_kg", sa.Numeric(precision=6, scale=2), nullable=False),
        sa.Column("declared_value_fcfa", sa.Integer(), server_default="0", nullable=False),
        sa.Column("transport_fee_fcfa", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=30), server_default="enregistre", nullable=False),
        sa.Column("payment_status", sa.String(length=30), server_default="aPayerAuRetrait", nullable=False),
        sa.Column("bus_license_plate", sa.String(length=50), nullable=True),
        sa.Column("driver_name", sa.String(length=100), nullable=True),
        sa.Column("is_photo_taken", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("photo_description", sa.Text(), nullable=True),
        sa.Column("recipient_cni_masked", sa.String(length=32), nullable=True),
        sa.Column("recipient_cni_encrypted", sa.LargeBinary(), nullable=True),
        sa.Column("recipient_cni_scanned", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("is_cod", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("cod_merchandise_amount_fcfa", sa.Integer(), server_default="0", nullable=False),
        sa.Column("cod_agency_commission_fcfa", sa.Integer(), server_default="0", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["agency_id"], ["agencies.id"], name=op.f("fk_parcels_agency_id_agencies"), ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_parcels")),
        sa.UniqueConstraint("id", "agency_id", name="uq_parcels_id_agency"),
        sa.CheckConstraint("weight_kg > 0", name="ck_parcels_weight_kg_positive"),
        sa.CheckConstraint("declared_value_fcfa >= 0", name="ck_parcels_declared_value_positive"),
        sa.CheckConstraint("transport_fee_fcfa >= 0", name="ck_parcels_transport_fee_positive"),
        sa.CheckConstraint("cod_merchandise_amount_fcfa >= 0", name="ck_parcels_cod_merchandise_positive"),
        sa.CheckConstraint("cod_agency_commission_fcfa >= 0", name="ck_parcels_cod_commission_positive"),
        sa.CheckConstraint(
            "status IN ('enregistre', 'chargeBus', 'enTransit', 'arriveDestination', 'retire')",
            name="ck_parcels_status",
        ),
        sa.CheckConstraint(
            "payment_status IN ('payeMomo', 'payeOrangeMoney', 'payeEspeces', 'aPayerAuRetrait')",
            name="ck_parcels_payment_status",
        ),
    )
    op.create_index(op.f("ix_parcels_agency_id"), "parcels", ["agency_id"], unique=False)
    op.create_index(op.f("ix_parcels_tracking_number"), "parcels", ["tracking_number"], unique=True)
    op.create_index("idx_parcels_agency_status", "parcels", ["agency_id", "status"])
    op.create_index("idx_parcels_agency_date", "parcels", ["agency_id", "created_at"])

    # 5. Table parcel_events
    op.create_table(
        "parcel_events",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("parcel_id", sa.Uuid(), nullable=False),
        sa.Column("agency_id", sa.Uuid(), nullable=False),
        sa.Column("event_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("title", sa.String(length=150), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("location", sa.String(length=150), nullable=False),
        sa.Column("is_completed", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("actor_id", sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(
            ["parcel_id", "agency_id"],
            ["parcels.id", "parcels.agency_id"],
            name="fk_parcel_events_parcel_agency",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["actor_id"], ["users.id"], name=op.f("fk_parcel_events_actor_id_users"), ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_parcel_events")),
    )
    op.create_index("idx_parcel_events_parcel_time", "parcel_events", ["parcel_id", "event_time"])
    op.create_index("idx_parcel_events_agency", "parcel_events", ["agency_id"])

    # 6. Table pickup_otps
    op.create_table(
        "pickup_otps",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("parcel_id", sa.Uuid(), nullable=False),
        sa.Column("agency_id", sa.Uuid(), nullable=False),
        sa.Column("hashed_code", sa.String(length=255), nullable=False),
        sa.Column("salt", sa.String(length=64), nullable=False),
        sa.Column("attempts_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("max_attempts", sa.Integer(), server_default="3", nullable=False),
        sa.Column("is_consumed", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["parcel_id", "agency_id"],
            ["parcels.id", "parcels.agency_id"],
            name="fk_pickup_otps_parcel_agency",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_pickup_otps")),
        sa.UniqueConstraint("parcel_id", name="uq_pickup_otps_parcel_id"),
        sa.CheckConstraint("attempts_count >= 0", name="ck_pickup_otps_attempts_positive"),
        sa.CheckConstraint("max_attempts > 0", name="ck_pickup_otps_max_attempts_positive"),
    )
    op.create_index("idx_pickup_otps_agency", "pickup_otps", ["agency_id"])

    # 7. Table payments
    op.create_table(
        "payments",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("parcel_id", sa.Uuid(), nullable=False),
        sa.Column("agency_id", sa.Uuid(), nullable=False),
        sa.Column("provider", sa.String(length=50), nullable=False),
        sa.Column("provider_reference", sa.String(length=150), nullable=True),
        sa.Column("internal_reference", sa.String(length=100), nullable=False),
        sa.Column("amount_fcfa", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=5), server_default="XAF", nullable=False),
        sa.Column("status", sa.String(length=30), nullable=False),
        sa.Column("customer_phone", sa.String(length=30), nullable=False),
        sa.Column("raw_webhook_payload", sa.JSON(), nullable=True),
        sa.Column("initiated_by", sa.Uuid(), nullable=True),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["parcel_id", "agency_id"],
            ["parcels.id", "parcels.agency_id"],
            name="fk_payments_parcel_agency",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(["agency_id"], ["agencies.id"], name=op.f("fk_payments_agency_id_agencies"), ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["initiated_by"], ["users.id"], name=op.f("fk_payments_initiated_by_users"), ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_payments")),
        sa.CheckConstraint("amount_fcfa > 0", name="ck_payments_amount_positive"),
        sa.CheckConstraint(
            "status IN ('cree', 'en_attente', 'confirme', 'echoue', 'annule')",
            name="ck_payments_status",
        ),
    )
    op.create_index(op.f("ix_payments_agency_id"), "payments", ["agency_id"], unique=False)
    op.create_index(op.f("ix_payments_internal_reference"), "payments", ["internal_reference"], unique=True)
    op.create_index("idx_payments_parcel", "payments", ["parcel_id"])
    op.create_index("idx_payments_provider_ref", "payments", ["provider", "provider_reference"])

    # 8. Table idempotency_keys
    op.create_table(
        "idempotency_keys",
        sa.Column("key", sa.String(length=128), nullable=False),
        sa.Column("agency_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=True),
        sa.Column("scope", sa.String(length=50), nullable=False),
        sa.Column("request_hash", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=20), server_default="IN_PROGRESS", nullable=False),
        sa.Column("response_code", sa.Integer(), nullable=True),
        sa.Column("response_body", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["agency_id"], ["agencies.id"], name=op.f("fk_idempotency_keys_agency_id_agencies"), ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name=op.f("fk_idempotency_keys_user_id_users"), ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("key", "agency_id", name=op.f("pk_idempotency_keys")),
        sa.CheckConstraint("status IN ('IN_PROGRESS', 'COMPLETED', 'FAILED')", name="ck_idempotency_status"),
    )
    op.create_index(op.f("ix_idempotency_keys_agency_id"), "idempotency_keys", ["agency_id"], unique=False)
    op.create_index(op.f("ix_idempotency_keys_expires_at"), "idempotency_keys", ["expires_at"], unique=False)


def downgrade() -> None:
    # Suppression en ordre inverse des dépendances relationnelles
    op.drop_table("idempotency_keys")
    op.drop_table("payments")
    op.drop_table("pickup_otps")
    op.drop_table("parcel_events")
    op.drop_table("parcels")
    op.drop_table("agency_members")
    op.drop_table("users")
    op.drop_table("agencies")
