"""Module de rate-limiting résilient par endpoint avec gestion de panne et proxys de confiance.

Prend en charge :
- Quotas différenciés par endpoint (IP pour public/login, identifiant utilisateur + IP pour change_password, etc.)
- Moteur partagé Redis distribué avec bascule de secours sur moteur local en mémoire
- Purge active et bornage mémoire (anti-fuite mémoire sous spam d'adresses IP)
- Politique de panne explicite par route (fail-closed sur login en production, fail-open maîtrisé sur consultation)
- Extraction sécurisée de l'adresse IP via proxys de confiance (rejet des faux en-têtes X-Forwarded-For)
"""
import asyncio
from collections import defaultdict, deque
import ipaddress
import logging
import time
from typing import Any, Callable, Deque, Dict, Optional, Tuple
from fastapi import HTTPException, Request, status
from app.core.config import settings

logger = logging.getLogger("colistrack.security.rate_limit")
MAX_MEMORY_KEYS = 10000


def extract_client_ip(request: Request) -> str:
    """Extrait l'adresse IP du client de manière sécurisée en filtrant les proxys de confiance.
    
    Règles de sécurité :
    1. Si le socket direct n'appartient pas à TRUSTED_PROXIES, X-Forwarded-For est formellement ignoré.
    2. Si le socket est un proxy approuvé, on parcourt X-Forwarded-For de droite à gauche pour
       identifier la première IP non certifiée (client réel).
    3. Toute adresse IP non conforme ou malformée est ignorée au profit de l'IP du socket.
    """
    socket_ip = request.client.host if request.client else "127.0.0.1"

    is_trusted = False
    try:
        sock_addr = ipaddress.ip_address(socket_ip)
        for tp in settings.TRUSTED_PROXIES:
            try:
                if sock_addr == ipaddress.ip_address(tp):
                    is_trusted = True
                    break
            except ValueError:
                pass
    except ValueError:
        is_trusted = False

    if not is_trusted:
        return socket_ip

    xff = request.headers.get("X-Forwarded-For")
    if not xff:
        return socket_ip

    raw_ips = [ip.strip() for ip in xff.split(",") if ip.strip()]
    if not raw_ips:
        return socket_ip

    for candidate in reversed(raw_ips):
        try:
            cand_addr = ipaddress.ip_address(candidate)
            cand_trusted = False
            for tp in settings.TRUSTED_PROXIES:
                try:
                    if cand_addr == ipaddress.ip_address(tp):
                        cand_trusted = True
                        break
                except ValueError:
                    pass
            if not cand_trusted:
                return candidate
        except ValueError:
            continue

    return raw_ips[0]


class InMemoryRateLimiter:
    """Limiteur en mémoire thread-safe et async à fenêtre glissante avec purge active."""

    def __init__(self, max_keys: int = MAX_MEMORY_KEYS):
        self._history: Dict[str, Deque[float]] = defaultdict(deque)
        self._lock = asyncio.Lock()
        self._max_keys = max_keys

    async def is_rate_limited(
        self,
        key: str,
        max_requests: int,
        window_seconds: int,
    ) -> Tuple[bool, int]:
        """Vérifie le quota via une fenêtre glissante. Retourne (est_bloqué, retry_after)."""
        now = time.time()
        window_start = now - window_seconds

        async with self._lock:
            # 1. Protection anti-croissance mémoire : purge si le dictionnaire dépasse le seuil max_keys
            if len(self._history) >= self._max_keys:
                expired_keys = [
                    k for k, dq in self._history.items()
                    if not dq or dq[-1] <= window_start
                ]
                for k in expired_keys:
                    del self._history[k]

            timestamps = self._history[key]
            # Purge des horodatages hors de la fenêtre glissante
            while timestamps and timestamps[0] <= window_start:
                timestamps.popleft()

            if len(timestamps) >= max_requests:
                oldest = timestamps[0]
                retry_after = max(1, int(oldest + window_seconds - now))
                return True, retry_after

            # Requête acceptée : enregistrer l'horodatage
            timestamps.append(now)
            return False, 0

    async def cleanup_inactive_keys(self, window_seconds: int = 60) -> int:
        """Supprime activement toutes les clés inactives sans horodatage récent."""
        now = time.time()
        window_start = now - window_seconds
        async with self._lock:
            keys_to_delete = [
                k for k, dq in self._history.items()
                if not dq or dq[-1] <= window_start
            ]
            for k in keys_to_delete:
                del self._history[k]
            return len(keys_to_delete)

    async def reset(self):
        """Réinitialise les compteurs (utile pour les tests)."""
        async with self._lock:
            self._history.clear()


# Instance singleton du limiteur local en mémoire
local_limiter = InMemoryRateLimiter()


class RedisRateLimiter:
    """Limiteur distribué basé sur Redis avec fenêtres glissantes atomiques."""

    def __init__(self, redis_url: Optional[str] = None):
        self.redis_url = redis_url
        self._client: Any = None

    async def _get_client(self):
        if self._client is None and self.redis_url:
            import redis.asyncio as aioredis
            self._client = aioredis.from_url(
                self.redis_url,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=2.0,
                socket_timeout=2.0,
            )
        return self._client

    async def is_rate_limited(
        self,
        key: str,
        max_requests: int,
        window_seconds: int,
    ) -> Tuple[bool, int]:
        """Vérifie le quota de manière atomique via un Sorted Set Redis."""
        client = await self._get_client()
        if client is None:
            raise ConnectionError("Client Redis non initialisé")

        now = time.time()
        window_start = now - window_seconds
        redis_key = f"colistrack:ratelimit:{key}"

        pipe = client.pipeline(transaction=True)
        pipe.zremrangebyscore(redis_key, 0, window_start)
        pipe.zcard(redis_key)
        pipe.zrange(redis_key, 0, 0, withscores=True)
        pipe.zadd(redis_key, {f"{now}": now})
        pipe.expire(redis_key, window_seconds + 5)
        results = await pipe.execute()

        current_count = results[1]
        oldest_entries = results[2]

        if current_count >= max_requests:
            oldest_score = oldest_entries[0][1] if oldest_entries else window_start
            retry_after = max(1, int(oldest_score + window_seconds - now))
            return True, retry_after

        return False, 0

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None


class RateLimitManager:
    """Gère l'arbitrage entre le limiteur distribué Redis et le limiteur local en mémoire."""

    def __init__(self):
        self.local = local_limiter
        self.redis: Optional[RedisRateLimiter] = (
            RedisRateLimiter(settings.REDIS_URL) if settings.REDIS_URL else None
        )

    async def check(
        self,
        category: str,
        key: str,
        max_requests: int,
        window_seconds: int = 60,
    ) -> Tuple[bool, int]:
        """Vérifie le quota selon la politique de panne spécifique à la catégorie."""
        if not settings.RATE_LIMITING_ENABLED:
            return False, 0

        # Tentative via Redis si configuré
        if self.redis and settings.REDIS_URL:
            try:
                return await self.redis.is_rate_limited(key, max_requests, window_seconds)
            except Exception as e:
                logger.warning(
                    "Échec de connexion Redis pour le rate-limiting (%s : %s). Bascule de repli : %s",
                    category,
                    key,
                    e,
                )
                if category == "login" and settings.ENVIRONMENT == "production":
                    # Fail-closed sur le login en production pour empêcher le brute-force non surveillé
                    raise HTTPException(
                        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                        detail="Service de sécurité temporairement indisponible. Veuillez réessayer.",
                    ) from e

        # Repli sur le limiteur local en mémoire
        try:
            return await self.local.is_rate_limited(key, max_requests, window_seconds)
        except Exception as e:
            logger.error("Erreur critique sur le limiteur local : %s", e)
            if category == "login":
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Service de sécurité temporairement indisponible. Veuillez réessayer.",
                ) from e
            elif category == "public":
                return False, 0
            else:
                return False, 0


# Gestionnaire centralisé de rate-limiting
rate_limit_manager = RateLimitManager()


def rate_limit(category: str, default_quota: int, window_seconds: int = 60) -> Callable:
    """Fabrique de dépendance FastAPI pour appliquer une limitation de débit par endpoint."""

    async def dependency(request: Request):
        if not settings.RATE_LIMITING_ENABLED:
            return

        # Construction de la clé de limitation selon la catégorie
        if category in ("login", "public"):
            client_ip = extract_client_ip(request)
            rate_key = f"{category}:{client_ip}"
        elif category == "change_password":
            user_id = getattr(request.state, "user_id", "unauthenticated")
            client_ip = extract_client_ip(request)
            rate_key = f"{category}:{user_id}:{client_ip}"
        elif category == "agency_context":
            agency_id = request.path_params.get("agency_id", "global")
            user_id = getattr(request.state, "user_id", extract_client_ip(request))
            rate_key = f"{category}:{user_id}:{agency_id}"
        else:
            user_id = getattr(request.state, "user_id", extract_client_ip(request))
            rate_key = f"{category}:{user_id}"

        # Détermination du quota selon la configuration Settings
        quota = default_quota
        if category == "login":
            quota = settings.RATE_LIMIT_LOGIN
        elif category == "change_password":
            quota = settings.RATE_LIMIT_CHANGE_PASSWORD
        elif category == "public":
            quota = settings.RATE_LIMIT_PUBLIC
        elif category == "auth_read":
            quota = settings.RATE_LIMIT_AUTH_READ
        elif category == "agency_context":
            quota = settings.RATE_LIMIT_AGENCY_CONTEXT
        elif category == "admin":
            quota = settings.RATE_LIMIT_ADMIN

        is_limited, retry_after = await rate_limit_manager.check(
            category=category,
            key=rate_key,
            max_requests=quota,
            window_seconds=window_seconds,
        )

        if is_limited:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Trop de requêtes. Veuillez réessayer plus tard.",
                headers={"Retry-After": str(retry_after)},
            )

    return dependency
