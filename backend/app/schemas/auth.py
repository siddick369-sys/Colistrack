"""Schémas Pydantic pour les requêtes et réponses d'authentification et de permissions."""
from typing import List
import uuid
from pydantic import BaseModel, ConfigDict, EmailStr, Field


class LoginRequest(BaseModel):
    """Requête de connexion avec identifiants."""
    email: str = Field(..., max_length=255, description="Adresse email de l'utilisateur")
    password: str = Field(..., min_length=1, max_length=128, description="Mot de passe en clair (max 128 caractères)")


class ChangePasswordRequest(BaseModel):
    """Requête de changement explicite de mot de passe par un utilisateur authentifié."""
    old_password: str = Field(..., min_length=1, max_length=128, description="Ancien mot de passe")
    new_password: str = Field(..., min_length=8, max_length=128, description="Nouveau mot de passe (min 8, max 128)")


class ChangePasswordResponse(BaseModel):
    """Confirmation de mise à jour sécurisée du mot de passe."""
    detail: str = Field(default="Mot de passe mis à jour avec succès.")


class TokenResponse(BaseModel):
    """Réponse contenant le jeton d'accès JWT."""
    access_token: str = Field(..., description="Jeton JWT signé")
    token_type: str = Field(default="bearer", description="Type de jeton")
    expires_in_minutes: int = Field(..., description="Durée de validité en minutes")


class UserResponse(BaseModel):
    """Représentation publique d'un utilisateur authentifié."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    full_name: str
    phone: str | None = None
    is_active: bool
    is_superuser: bool


class AgencyContextResponse(BaseModel):
    """Appartenance d'un utilisateur à une agence et son rôle effectif."""
    model_config = ConfigDict(from_attributes=True)

    agency_id: uuid.UUID
    agency_code: str
    agency_name: str
    role: str
    is_active: bool


class AuthMeResponse(BaseModel):
    """Informations de profil et liste des agences accessibles pour l'utilisateur."""
    user: UserResponse
    agencies: List[AgencyContextResponse]


class AgencyContextDiagnosticResponse(BaseModel):
    """Réponse de validation de contexte d'agence et vérification RBAC."""
    agency_id: uuid.UUID
    agency_code: str
    agency_name: str
    user_id: uuid.UUID
    user_email: str
    role: str
    is_active: bool
