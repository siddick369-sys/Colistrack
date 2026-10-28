"""Modèle SQLAlchemy 2.0 pour les transactions financières et paiements Mobile Money."""
from datetime import datetime
from typing import TYPE_CHECKING, Any, Dict, Optional
import uuid
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    JSON,
    String,
    Uuid,
    event,
    inspect,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, utcnow
from app.db.encrypted_type import EncryptedString

if TYPE_CHECKING:
    from app.models.agency import Agency
    from app.models.parcel import Parcel
    from app.models.user import User


class Payment(Base):
    """Enregistre un flux financier lié à un colis avec référence interne unique."""

    __tablename__ = "payments"
    __table_args__ = (
        # Clé étrangère composite interdisant formellement l'association d'un paiement à un colis tiers
        ForeignKeyConstraint(
            ["parcel_id", "agency_id"],
            ["parcels.id", "parcels.agency_id"],
            ondelete="RESTRICT",
            name="fk_payments_parcel_agency",
        ),
        CheckConstraint("amount_fcfa > 0", name="ck_payments_amount_positive"),
        CheckConstraint(
            "status IN ('cree', 'en_attente', 'confirme', 'echoue', 'annule')",
            name="ck_payments_status",
        ),
        Index("idx_payments_parcel", "parcel_id"),
        Index("idx_payments_provider_ref", "provider", "provider_reference"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    parcel_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        nullable=False,
    )
    agency_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("agencies.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    provider: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )  # CAMPAY, MTN_DIRECT, ORANGE_DIRECT, ESPECES
    provider_reference: Mapped[Optional[str]] = mapped_column(
        String(150),
        nullable=True,
    )
    internal_reference: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        nullable=False,
        index=True,
    )  # Ex: TRX-XXXX-XXXX-XXXX (60 bits d'entropie)
    amount_fcfa: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    currency: Mapped[str] = mapped_column(
        String(5),
        default="XAF",
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )  # cree, en_attente, confirme, echoue, annule
    customer_phone: Mapped[str] = mapped_column(
        EncryptedString,
        nullable=False,
    )
    is_pii_encrypted: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="false",
        nullable=False,
    )
    raw_webhook_payload: Mapped[Optional[Dict[str, Any]]] = mapped_column(
        JSON,
        nullable=True,
    )
    initiated_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    confirmed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
        nullable=False,
    )

    # Relations
    parcel: Mapped["Parcel"] = relationship(
        "Parcel",
        back_populates="payments",
        foreign_keys=[parcel_id, agency_id],
        overlaps="payments",
    )
    agency: Mapped["Agency"] = relationship(
        "Agency",
        back_populates="payments",
        overlaps="parcel,payments",
    )
    initiator: Mapped[Optional["User"]] = relationship(
        "User",
    )

    def __repr__(self) -> str:
        return f"<Payment(id={self.id}, internal_ref='{self.internal_reference}', amount={self.amount_fcfa}, status='{self.status}')>"


@event.listens_for(Payment, "before_insert")
def _payment_before_insert(mapper, connection, target: Payment) -> None:
    """À l'insertion ORM, customer_phone est chiffré par EncryptedString."""
    target.is_pii_encrypted = True


@event.listens_for(Payment, "before_update")
def _payment_before_update(mapper, connection, target: Payment) -> None:
    """À la mise à jour ORM, ne certifie is_pii_encrypted=True que si customer_phone est chiffré."""
    if target.is_pii_encrypted:
        return

    insp = inspect(target)
    if insp.attrs["customer_phone"].history.has_changes():
        target.is_pii_encrypted = True
