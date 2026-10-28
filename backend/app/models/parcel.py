"""Modèle SQLAlchemy 2.0 pour les colis (Parcels) avec cloisonnement multi-agences strict."""
from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING, List, Optional
import uuid
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    event,
    inspect,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, utcnow
from app.db.encrypted_bytes_type import EncryptedBytes
from app.db.encrypted_type import EncryptedString

if TYPE_CHECKING:
    from app.models.agency import Agency
    from app.models.parcel_event import ParcelEvent
    from app.models.pickup_otp import PickupOtp
    from app.models.payment import Payment


class Parcel(Base):
    """Représente un colis acheminé par une agence."""

    __tablename__ = "parcels"
    __table_args__ = (
        # Clé unique composite assurant le cloisonnement multi-agences au niveau du SGBD
        UniqueConstraint("id", "agency_id", name="uq_parcels_id_agency"),
        # Contraintes de domaine et d'intégrité financière
        CheckConstraint("weight_kg > 0", name="ck_parcels_weight_kg_positive"),
        CheckConstraint("declared_value_fcfa >= 0", name="ck_parcels_declared_value_positive"),
        CheckConstraint("transport_fee_fcfa >= 0", name="ck_parcels_transport_fee_positive"),
        CheckConstraint("cod_merchandise_amount_fcfa >= 0", name="ck_parcels_cod_merchandise_positive"),
        CheckConstraint("cod_agency_commission_fcfa >= 0", name="ck_parcels_cod_commission_positive"),
        CheckConstraint(
            "status IN ('enregistre', 'chargeBus', 'enTransit', 'arriveDestination', 'retire')",
            name="ck_parcels_status",
        ),
        CheckConstraint(
            "payment_status IN ('payeMomo', 'payeOrangeMoney', 'payeEspeces', 'aPayerAuRetrait')",
            name="ck_parcels_payment_status",
        ),
        Index("idx_parcels_agency_status", "agency_id", "status"),
        Index("idx_parcels_agency_date", "agency_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    tracking_number: Mapped[str] = mapped_column(
        String(32),
        unique=True,
        nullable=False,
        index=True,
    )
    agency_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("agencies.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    # Informations Expéditeur
    sender_name: Mapped[str] = mapped_column(
        EncryptedString,
        nullable=False,
    )
    sender_phone: Mapped[str] = mapped_column(
        EncryptedString,
        nullable=False,
    )
    origin_city: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    origin_branch: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    # Informations Destinataire
    recipient_name: Mapped[str] = mapped_column(
        EncryptedString,
        nullable=False,
    )
    recipient_phone: Mapped[str] = mapped_column(
        EncryptedString,
        nullable=False,
    )
    destination_city: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    destination_branch: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    pickup_counter: Mapped[str] = mapped_column(
        String(100),
        default="Guichet 1 (Principal)",
        nullable=False,
    )

    # Caractéristiques et Tarification
    parcel_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    weight_kg: Mapped[Decimal] = mapped_column(
        Numeric(6, 2),
        nullable=False,
    )
    declared_value_fcfa: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    transport_fee_fcfa: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    # Cycle de vie et Paiement
    status: Mapped[str] = mapped_column(
        String(30),
        default="enregistre",
        nullable=False,
    )
    payment_status: Mapped[str] = mapped_column(
        String(30),
        default="aPayerAuRetrait",
        nullable=False,
    )

    # Acheminement et Logistique
    bus_license_plate: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
    )
    driver_name: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
    )
    is_photo_taken: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    photo_description: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )

    # Protection des Données Personnelles (CNI Destinataire)
    recipient_cni_masked: Mapped[Optional[str]] = mapped_column(
        String(32),
        nullable=True,
    )
    recipient_cni_encrypted: Mapped[Optional[bytes]] = mapped_column(
        EncryptedBytes,
        nullable=True,
    )
    recipient_cni_scanned: Mapped[bool] = mapped_column(
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

    # Cash On Delivery (Contre-Remboursement)
    is_cod: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    cod_merchandise_amount_fcfa: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    cod_agency_commission_fcfa: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    # Horodatages
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
    agency: Mapped["Agency"] = relationship(
        "Agency",
        back_populates="parcels",
    )
    events: Mapped[List["ParcelEvent"]] = relationship(
        "ParcelEvent",
        back_populates="parcel",
        cascade="all, delete-orphan",
        foreign_keys="[ParcelEvent.parcel_id, ParcelEvent.agency_id]",
    )
    otp: Mapped[Optional["PickupOtp"]] = relationship(
        "PickupOtp",
        back_populates="parcel",
        uselist=False,
        cascade="all, delete-orphan",
        foreign_keys="[PickupOtp.parcel_id, PickupOtp.agency_id]",
    )
    payments: Mapped[List["Payment"]] = relationship(
        "Payment",
        back_populates="parcel",
        foreign_keys="[Payment.parcel_id, Payment.agency_id]",
        overlaps="payments",
    )

    def __repr__(self) -> str:
        return f"<Parcel(id={self.id}, tracking='{self.tracking_number}', agency_id={self.agency_id}, status='{self.status}')>"


@event.listens_for(Parcel, "before_insert")
def _parcel_before_insert(mapper, connection, target: Parcel) -> None:
    """À l'insertion ORM, tous les champs PII non nuls sont chiffrés par les TypeDecorators."""
    target.is_pii_encrypted = True


@event.listens_for(Parcel, "before_update")
def _parcel_before_update(mapper, connection, target: Parcel) -> None:
    """À la mise à jour ORM, ne certifie is_pii_encrypted=True que si TOUS les PII sont chiffrés.

    Si la ligne en base était historique (is_pii_encrypted=False) :
    - Une mise à jour partielle des champs texte ne suffit pas si l'un d'eux n'est pas modifié.
    - Une mise à jour des 4 champs texte ne suffit pas si recipient_cni_encrypted est non-nul
      et n'a pas été modifié dans cette transaction.
    - Des modifications sur des champs non-PII (status, tracking, etc.) ne modifient jamais le marqueur.
    - is_pii_encrypted ne passe à True que si :
      1. Les 4 champs texte obligatoires ont tous été modifiés dans cette transaction
         (et sont donc chiffrés par EncryptedString au flush).
      2. ET recipient_cni_encrypted est soit NULL (absent), soit également modifié dans cette
         transaction (chiffré par EncryptedBytes au flush).
    """
    if target.is_pii_encrypted:
        return

    insp = inspect(target)
    text_pii_cols = ["sender_name", "sender_phone", "recipient_name", "recipient_phone"]
    all_text_changed = all(insp.attrs[col].history.has_changes() for col in text_pii_cols)
    cni_changed = insp.attrs["recipient_cni_encrypted"].history.has_changes()

    if all_text_changed and (target.recipient_cni_encrypted is None or cni_changed):
        target.is_pii_encrypted = True
