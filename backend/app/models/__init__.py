"""Agrégateur des modèles SQLAlchemy pour découverte centralisée par Alembic et l'application."""
from app.db.base import Base, utcnow
from app.models.agency import Agency
from app.models.user import User
from app.models.agency_member import AgencyMember
from app.models.parcel import Parcel
from app.models.parcel_event import ParcelEvent
from app.models.pickup_otp import PickupOtp
from app.models.payment import Payment
from app.models.idempotency import IdempotencyKey

__all__ = [
    "Base",
    "utcnow",
    "Agency",
    "User",
    "AgencyMember",
    "Parcel",
    "ParcelEvent",
    "PickupOtp",
    "Payment",
    "IdempotencyKey",
]
