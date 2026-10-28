"""Modèle SQLAlchemy 2.0 pour les utilisateurs de la plateforme ColisTrack."""
from datetime import datetime
from typing import TYPE_CHECKING, List, Optional
import uuid
from sqlalchemy import Boolean, DateTime, Integer, String, Uuid, event, inspect
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, utcnow
from app.db.encrypted_type import EncryptedString

if TYPE_CHECKING:
    from app.models.agency_member import AgencyMember


class User(Base):
    """Représente un utilisateur authentifié sur la plateforme."""

    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        index=True,
    )
    hashed_password: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    full_name: Mapped[str] = mapped_column(
        EncryptedString,
        nullable=False,
    )
    phone: Mapped[Optional[str]] = mapped_column(
        EncryptedString,
        nullable=True,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    is_superuser: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    is_pii_encrypted: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="false",
        nullable=False,
    )
    token_version: Mapped[int] = mapped_column(
        Integer,
        default=1,
        server_default="1",
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )

    # Relations
    memberships: Mapped[List["AgencyMember"]] = relationship(
        "AgencyMember",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<User(id={self.id}, email='{self.email}', full_name='{self.full_name}')>"


@event.listens_for(User, "before_insert")
def _user_before_insert(mapper, connection, target: User) -> None:
    """À l'insertion ORM, full_name et phone (si présent) sont chiffrés par EncryptedString."""
    target.is_pii_encrypted = True


@event.listens_for(User, "before_update")
def _user_before_update(mapper, connection, target: User) -> None:
    """À la mise à jour ORM, ne certifie is_pii_encrypted=True que si TOUS les champs PII sont chiffrés.

    Si la ligne en base était historique (is_pii_encrypted=False) :
    - Si seul full_name est modifié alors que phone est non-nul : phone reste en clair en base,
      donc is_pii_encrypted DOIT rester False pour que migrate_pii_data.py puisse le traiter.
    - Si seul phone est modifié alors que full_name n'a pas changé : full_name reste en clair en base,
      donc is_pii_encrypted DOIT rester False.
    - Si des champs non-PII seuls sont modifiés : is_pii_encrypted DOIT rester False.
    - is_pii_encrypted ne passe à True que si TOUS les champs PII non nuls sont modifiés (et donc
      chiffrés par EncryptedString lors du flush actuel) : full_name a changé ET (phone is None OU phone a changé).
    """
    if target.is_pii_encrypted:
        return

    insp = inspect(target)
    full_name_changed = insp.attrs["full_name"].history.has_changes()
    phone_changed = insp.attrs["phone"].history.has_changes()

    if full_name_changed and (target.phone is None or phone_changed):
        target.is_pii_encrypted = True
