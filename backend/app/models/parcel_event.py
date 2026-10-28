"""Modèle SQLAlchemy 2.0 pour l'historique d'événements de suivi d'un colis."""
from datetime import datetime
from typing import TYPE_CHECKING, Optional
import uuid
from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, utcnow

if TYPE_CHECKING:
    from app.models.parcel import Parcel
    from app.models.user import User


class ParcelEvent(Base):
    """Étape immuable du suivi logistique d'un colis."""

    __tablename__ = "parcel_events"
    __table_args__ = (
        # Clé étrangère composite garantissant le rattachement strict à l'agence du colis
        ForeignKeyConstraint(
            ["parcel_id", "agency_id"],
            ["parcels.id", "parcels.agency_id"],
            ondelete="CASCADE",
            name="fk_parcel_events_parcel_agency",
        ),
        Index("idx_parcel_events_parcel_time", "parcel_id", "event_time"),
        Index("idx_parcel_events_agency", "agency_id"),
    )

    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )
    parcel_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        nullable=False,
    )
    agency_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        nullable=False,
    )
    event_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )
    title: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )
    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    location: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )
    is_completed: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    actor_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Relations
    parcel: Mapped["Parcel"] = relationship(
        "Parcel",
        back_populates="events",
        foreign_keys=[parcel_id, agency_id],
    )
    actor: Mapped[Optional["User"]] = relationship(
        "User",
    )

    def __repr__(self) -> str:
        return f"<ParcelEvent(id={self.id}, parcel_id={self.parcel_id}, title='{self.title}')>"
