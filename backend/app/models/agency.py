"""Modèle SQLAlchemy 2.0 pour les agences (Tenants SaaS multi-agences)."""
from datetime import datetime
from typing import TYPE_CHECKING, List
import uuid
from sqlalchemy import Boolean, DateTime, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, utcnow

if TYPE_CHECKING:
    from app.models.agency_member import AgencyMember
    from app.models.parcel import Parcel
    from app.models.payment import Payment
    from app.models.idempotency import IdempotencyKey


class Agency(Base):
    """Représente une agence de transport (tenant isolé du SaaS)."""

    __tablename__ = "agencies"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )
    code: Mapped[str] = mapped_column(
        String(10),
        unique=True,
        nullable=False,
        index=True,
    )
    phone: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )
    city_headquarters: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )

    # Relations
    members: Mapped[List["AgencyMember"]] = relationship(
        "AgencyMember",
        back_populates="agency",
        cascade="all, delete-orphan",
    )
    parcels: Mapped[List["Parcel"]] = relationship(
        "Parcel",
        back_populates="agency",
    )
    payments: Mapped[List["Payment"]] = relationship(
        "Payment",
        back_populates="agency",
    )
    idempotency_keys: Mapped[List["IdempotencyKey"]] = relationship(
        "IdempotencyKey",
        back_populates="agency",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Agency(id={self.id}, code='{self.code}', name='{self.name}')>"
