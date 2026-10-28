"""Modèle SQLAlchemy 2.0 pour la gestion atomique de l'idempotence réseau multi-agences."""
from datetime import datetime
from typing import TYPE_CHECKING, Any, Dict, Optional
import uuid
from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    String,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, utcnow

if TYPE_CHECKING:
    from app.models.agency import Agency
    from app.models.user import User


class IdempotencyKey(Base):
    """Verrou et mémoire de réponse d'idempotence pour les mutations d'API critiques."""

    __tablename__ = "idempotency_keys"
    __table_args__ = (
        CheckConstraint(
            "status IN ('IN_PROGRESS', 'COMPLETED', 'FAILED')",
            name="ck_idempotency_status",
        ),
    )

    # Clé primaire composite : clé d'idempotence + agence (isolation multi-tenant stricte)
    key: Mapped[str] = mapped_column(
        String(128),
        primary_key=True,
    )
    agency_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("agencies.id", ondelete="CASCADE"),
        primary_key=True,
        index=True,
    )

    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    scope: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )
    request_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
    )  # SHA-256 du body normalisé
    status: Mapped[str] = mapped_column(
        String(20),
        default="IN_PROGRESS",
        nullable=False,
    )
    response_code: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
    )
    response_body: Mapped[Optional[Dict[str, Any]]] = mapped_column(
        JSON,
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )

    # Relations
    agency: Mapped["Agency"] = relationship(
        "Agency",
        back_populates="idempotency_keys",
    )
    user: Mapped[Optional["User"]] = relationship(
        "User",
    )

    def __repr__(self) -> str:
        return f"<IdempotencyKey(key='{self.key}', agency_id={self.agency_id}, status='{self.status}')>"
