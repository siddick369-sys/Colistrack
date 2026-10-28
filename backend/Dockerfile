# ==============================================================================
# COLISTRACK CAMEROUN V2 — Dockerfile Backend FastAPI
# Image de base explicitement versionnée : Python 3.11-slim (Debian Bookworm)
# ==============================================================================
FROM python:3.11-slim

# Configuration d'environnement Python durcie
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    PORT=8000

# Création d'un groupe et d'un utilisateur système non privilégié
RUN groupadd --system --gid 10001 appgroup && \
    useradd --system --uid 10001 --gid appgroup --create-home --home-dir /home/appuser appuser

WORKDIR /app

# Installation des dépendances Python épinglées
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copie du code source applicatif uniquement (sans tests ni secrets)
COPY app/ ./app/

# Attribution des droits à l'utilisateur non privilégié
RUN chown -R appuser:appgroup /app

# Bascule vers l'utilisateur non privilégié
USER appuser

# Exposition du port HTTP interne
EXPOSE 8000

# Healthcheck Docker standardisé via Python sans outil tiers
HEALTHCHECK --interval=20s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://localhost:' + str(8000) + '/healthcheck').getcode() == 200 else 1)"

# Commande de démarrage uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
