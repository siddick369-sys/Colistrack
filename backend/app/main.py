import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.api.health import router as health_router
from app.api.auth import router as auth_router
from app.core.config import settings
from app.core.exceptions import DecryptionError

logger = logging.getLogger("colistrack.main")


def create_application() -> FastAPI:
    """Fabrique d'application FastAPI avec configuration et middlewares sécurisés."""
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
        redoc_url="/redoc" if settings.ENVIRONMENT != "production" else None,
        openapi_url="/openapi.json" if settings.ENVIRONMENT != "production" else None,
    )

    # Middleware CORS avec origines explicitement restreintes
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )

    # Gestionnaire d'exception de déchiffrement : interdiction de fuiter des détails cryptographiques
    @app.exception_handler(DecryptionError)
    async def decryption_exception_handler(request, exc: DecryptionError):
        logger.critical(
            "Interception d'une erreur critique de déchiffrement: colonne=%s, motif=%s",
            exc.column_name,
            exc.error_type,
        )
        return JSONResponse(
            status_code=500,
            content={"detail": "Erreur interne de sécurité lors du traitement des données."},
        )

    # Enregistrement des routeurs
    app.include_router(health_router)
    app.include_router(auth_router)

    return app


app = create_application()
