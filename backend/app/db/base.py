"""Définition de la classe de base déclarative SQLAlchemy 2.0 et conventions de nommage."""
from datetime import datetime, timezone
from sqlalchemy import MetaData
from sqlalchemy.orm import DeclarativeBase

# Convention stricte de nommage des contraintes PostgreSQL / SQLite
# pour garantir la cohérence des migrations Alembic sans doublons ni collisions
POSTGRES_NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    """Classe de base déclarative pour tous les modèles relationnels."""
    metadata = MetaData(naming_convention=POSTGRES_NAMING_CONVENTION)


def utcnow() -> datetime:
    """Fournit un horodatage UTC conscient (timezone-aware) garanti."""
    return datetime.now(timezone.utc)
