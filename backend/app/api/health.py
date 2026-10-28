from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, ConfigDict
from app.core.config import settings
from app.core.rate_limit import rate_limit


router = APIRouter(tags=["Health"])


class HealthResponse(BaseModel):
    """Schéma de réponse minimal et sûr pour le contrôle de santé."""

    status: str

    model_config = ConfigDict(extra="forbid")


@router.get(
    "/healthcheck",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(rate_limit("public", default_quota=settings.RATE_LIMIT_PUBLIC, window_seconds=60))],
    summary="Contrôle de santé du service FastAPI",
    description="Retourne le statut opérationnel minimal du processus FastAPI sans exposer de données internes.",
)
async def healthcheck() -> HealthResponse:
    """Endpoint de santé minimal pour orchestration et probes de surveillance."""
    return HealthResponse(status="ok")
