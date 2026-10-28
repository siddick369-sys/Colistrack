"""Modèle SQLAlchemy 2.0 pour le code secret (OTP) de retrait sécurisé."""
from datetime import datetime
from typing import TYPE_CHECKING, Optional
import uuid
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, utcnow

if TYPE_CHECKING:
    from app.models.parcel import Parcel


class PickupOtp(Base):
    """Stockage sécurisé (haché avec sel) du code secret de retrait d'un colis."""

    __tablename__ = "pickup_otps"
    __table_args__ = (
        ForeignKeyConstraint(
            ["parcel_id", "agency_id"],
            ["parcels.id", "parcels.agency_id"],
            ondelete="CASCADE",
            name="fk_pickup_otps_parcel_agency",
        ),
        CheckConstraint("attempts_count >= 0", name="ck_pickup_otps_attempts_positive"),
        CheckConstraint("max_attempts > 0", name="ck_pickup_otps_max_attempts_positive"),
        Index("idx_pickup_otps_agency", "agency_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    parcel_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        unique=True,
        nullable=False,
    )
    agency_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        nullable=False,
    )
    hashed_code: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    salt: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
    )
    attempts_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    max_attempts: Mapped[int] = mapped_column(
        Integer,
        default=3,
        nullable=False,
    )
    is_consumed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    consumed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )

    # Relations
    parcel: Mapped["Parcel"] = relationship(
        "Parcel",
        back_populates="otp",
        foreign_keys=[parcel_id, agency_id],
    )

    def __repr__(self) -> str:
        return f"<PickupOtp(id={self.id}, parcel_id={self.parcel_id}, is_consumed={self.is_consumed})>"
