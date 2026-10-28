"""Configuration des moteurs de base de données et fabriques de sessions SQLAlchemy."""
from typing import AsyncGenerator
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.core.config import settings

# Moteur asynchrone principal (FastAPI / asyncpg)
async_engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    future=True,
    pool_pre_ping=True,
)

# Fabrique de sessions asynchrones
AsyncSessionLocal = async_sessionmaker(
    bind=async_engine,
    class_=AsyncSession,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)

# Moteur synchrone pour les migrations Alembic et outils de maintenance (psycopg2)
sync_engine = create_engine(
    settings.SYNC_DATABASE_URL,
    echo=False,
    future=True,
    pool_pre_ping=True,
)


async def get_async_session() -> AsyncGenerator[AsyncSession, None]:
    """Dépendance FastAPI injectant une session asynchrone isolée par requête."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
