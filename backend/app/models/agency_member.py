"""Modèle SQLAlchemy 2.0 pour l'appartenance d'un utilisateur à une agence (Tenancy)."""
from datetime import datetime
from typing import TYPE_CHECKING
import uuid
from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, utcnow

if TYPE_CHECKING:
    from app.models.agency import Agency
    from app.models.user import User


class AgencyMember(Base):
    """Liaison entre un utilisateur et une agence avec rôle métier associé."""

    __tablename__ = "agency_members"
    __table_args__ = (
        UniqueConstraint("agency_id", "user_id", name="uq_agency_members_agency_user"),
        CheckConstraint(
            "role IN ('agencyManager', 'agencyAgent')",
            name="ck_agency_members_role",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    agency_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("agencies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(
        String(30),
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
    agency: Mapped["Agency"] = relationship(
        "Agency",
        back_populates="members",
    )
    user: Mapped["User"] = relationship(
        "User",
        back_populates="memberships",
    )

    def __repr__(self) -> str:
        return f"<AgencyMember(id={self.id}, agency_id={self.agency_id}, user_id={self.user_id}, role='{self.role}')>"
