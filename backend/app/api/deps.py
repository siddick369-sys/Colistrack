"""Injections de dépendances FastAPI pour l'authentification et l'autorisation RBAC multi-agences."""
from dataclasses import dataclass
from typing import AsyncGenerator, Callable, List
import uuid
from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload
from app.core.security import decode_access_token
from app.db.session import get_async_session
from app.models.agency import Agency
from app.models.agency_member import AgencyMember
from app.models.user import User

# Schéma OAuth2 Bearer configuré
oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/api/v1/auth/login",
    auto_error=False,
)


@dataclass
class AgencyContext:
    """Représente le contexte de travail validé d'un utilisateur au sein d'une agence."""
    agency: Agency
    member: AgencyMember
    user: User
    role: str


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Fournit la session de base de données asynchrone pour la requête."""
    async for session in get_async_session():
        yield session


async def get_current_user(
    request: Request,
    token: str | None = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Valide le jeton Bearer et extrait l'utilisateur correspondant depuis la base."""
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentification requise : jeton d'accès manquant",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_access_token(token)
    uid_str = payload.get("uid")
    if not uid_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Jeton invalide : identifiant utilisateur absent",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        user_uuid = uuid.UUID(uid_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Jeton invalide : format d'identifiant incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        )

    result = await db.execute(select(User).where(User.id == user_uuid))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utilisateur introuvable",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # ARCH-02 : Validation stricte de concordance entre la revendication 'sub' et le compte réel
    sub_email = payload.get("sub")
    if not sub_email or user.email.lower().strip() != str(sub_email).lower().strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Jeton invalide : incohérence entre l'identité et le compte utilisateur",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # SEC-04 : Validation de la version du jeton pour révocation immédiate (ex: post changement de mot de passe)
    token_ver = payload.get("ver")
    if token_ver is not None and token_ver != user.token_version:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Jeton révoqué ou session obsolète suite à un événement de sécurité",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Enregistrement de l'identifiant pour le rate-limiter
    request.state.user_id = str(user.id)

    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user),
) -> User:
    """Vérifie que le compte de l'utilisateur authentifié est actif."""
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte utilisateur inactif ou suspendu",
        )
    return current_user


async def get_agency_context(
    agency_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
) -> AgencyContext:
    """Valide l'appartenance active de l'utilisateur à l'agence ciblée et extrait son rôle réel en base."""
    result = await db.execute(
        select(AgencyMember)
        .options(joinedload(AgencyMember.agency))
        .where(
            AgencyMember.user_id == current_user.id,
            AgencyMember.agency_id == agency_id,
        )
    )
    membership = result.scalar_one_or_none()

    if not membership:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accès interdit : vous n'êtes pas membre de cette agence",
        )

    if not membership.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accès interdit : votre appartenance à cette agence est désactivée",
        )

    if not membership.agency.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accès interdit : l'agence demandée est désactivée",
        )

    return AgencyContext(
        agency=membership.agency,
        member=membership,
        user=current_user,
        role=membership.role,
    )


def require_role(allowed_roles: List[str]) -> Callable:
    """Fabrique de dépendance RBAC validant que le rôle actif dans l'agence est autorisé."""
    async def role_checker(
        context: AgencyContext = Depends(get_agency_context),
    ) -> AgencyContext:
        if context.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission insuffisante pour cette action. Rôles autorisés : {allowed_roles}",
            )
        return context

    return role_checker
