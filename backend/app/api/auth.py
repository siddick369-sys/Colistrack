"""Endpoints d'authentification, de profil et de validation des contextes RBAC multi-agences."""
from typing import List
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload
from app.api.deps import (
    AgencyContext,
    get_agency_context,
    get_current_active_user,
    get_db,
    require_role,
)
from app.core.config import settings
from app.core.rate_limit import rate_limit
from app.core.security import (
    create_access_token,
    get_password_hash,
    verify_dummy_password,
    verify_password,
)
from app.models.agency_member import AgencyMember
from app.models.user import User
from app.schemas.auth import (
    AgencyContextDiagnosticResponse,
    AgencyContextResponse,
    AuthMeResponse,
    ChangePasswordRequest,
    ChangePasswordResponse,
    LoginRequest,
    TokenResponse,
    UserResponse,
)

router = APIRouter(prefix="/api/v1/auth", tags=["Authentification & RBAC"])


@router.post(
    "/login",
    response_model=TokenResponse,
    dependencies=[Depends(rate_limit("login", default_quota=settings.RATE_LIMIT_LOGIN, window_seconds=60))],
)
async def login(
    credentials: LoginRequest,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Authentifie un utilisateur et émet un jeton d'accès JWT signé."""
    email_clean = credentials.email.strip().lower()
    result = await db.execute(
        select(User).where(func.lower(User.email) == email_clean)
    )
    user = result.scalar_one_or_none()

    # SEC-02 : Protection anti-timing par calcul cryptographique fictif si l'utilisateur est inexistant
    if not user:
        verify_dummy_password(credentials.password)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiants de connexion invalides",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Vérification du mot de passe
    if not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiants de connexion invalides",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Compte suspendu
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ce compte utilisateur est désactivé ou suspendu",
        )

    # SEC-03 & Addendum A : ZÉRO re-hachage automatique des empreintes historiques au login
    # pour empêcher l'adoption silencieuse d'un suffixe post-72 octets

    token = create_access_token(
        subject=user.email,
        user_id=str(user.id),
        token_version=user.token_version,
    )

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in_minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES,
    )


@router.post(
    "/change-password",
    response_model=ChangePasswordResponse,
)
async def change_password(
    data: ChangePasswordRequest,
    current_user: User = Depends(get_current_active_user),
    _: None = Depends(rate_limit("change_password", default_quota=settings.RATE_LIMIT_CHANGE_PASSWORD, window_seconds=60)),
    db: AsyncSession = Depends(get_db),
) -> ChangePasswordResponse:
    """Permet à un utilisateur actif de changer son mot de passe, d'invalider ses sessions existantes et de migrer vers le format moderne v1."""
    if not verify_password(data.old_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="L'ancien mot de passe fourni est incorrect",
        )

    # Génération de la nouvelle empreinte moderne versionnée ($v1$sha256$)
    new_hash = get_password_hash(data.new_password)
    current_user.hashed_password = new_hash
    current_user.token_version += 1
    await db.commit()

    return ChangePasswordResponse(detail="Mot de passe mis à jour avec succès.")


@router.get(
    "/me",
    response_model=AuthMeResponse,
    dependencies=[Depends(rate_limit("auth_read", default_quota=settings.RATE_LIMIT_AUTH_READ, window_seconds=60))],
)
async def get_me(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
) -> AuthMeResponse:
    """Retourne l'identité de l'utilisateur actif et l'ensemble de ses appartenances d'agence."""
    result = await db.execute(
        select(AgencyMember)
        .options(joinedload(AgencyMember.agency))
        .where(AgencyMember.user_id == current_user.id)
    )
    memberships = result.scalars().all()

    agencies_list: List[AgencyContextResponse] = [
        AgencyContextResponse(
            agency_id=m.agency_id,
            agency_code=m.agency.code,
            agency_name=m.agency.name,
            role=m.role,
            is_active=m.is_active and m.agency.is_active,
        )
        for m in memberships
    ]

    return AuthMeResponse(
        user=UserResponse.model_validate(current_user),
        agencies=agencies_list,
    )


@router.get(
    "/agency-context/{agency_id}",
    response_model=AgencyContextDiagnosticResponse,
    dependencies=[Depends(rate_limit("agency_context", default_quota=settings.RATE_LIMIT_AGENCY_CONTEXT, window_seconds=60))],
)
async def verify_agency_context(
    context: AgencyContext = Depends(get_agency_context),
) -> AgencyContextDiagnosticResponse:
    """Valide l'accès et extrait les privilèges effectifs pour une agence spécifique."""
    return AgencyContextDiagnosticResponse(
        agency_id=context.agency.id,
        agency_code=context.agency.code,
        agency_name=context.agency.name,
        user_id=context.user.id,
        user_email=context.user.email,
        role=context.role,
        is_active=context.member.is_active,
    )


@router.get(
    "/agency-admin-check/{agency_id}",
    response_model=AgencyContextDiagnosticResponse,
    dependencies=[Depends(rate_limit("admin", default_quota=settings.RATE_LIMIT_ADMIN, window_seconds=60))],
)
async def verify_agency_manager_role(
    context: AgencyContext = Depends(require_role(["agencyManager"])),
) -> AgencyContextDiagnosticResponse:
    """Route protégée RBAC exigeant impérativement le rôle 'agencyManager' dans l'agence demandée.
    
    ARCH-01 : Désactivée formellement en production avec un code HTTP 404.
    """
    if settings.ENVIRONMENT == "production":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Endpoint introuvable",
        )

    return AgencyContextDiagnosticResponse(
        agency_id=context.agency.id,
        agency_code=context.agency.code,
        agency_name=context.agency.name,
        user_id=context.user.id,
        user_email=context.user.email,
        role=context.role,
        is_active=context.member.is_active,
    )
