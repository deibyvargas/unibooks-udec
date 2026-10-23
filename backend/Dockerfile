# ==============================================================================
# DOCKERFILE - BACKEND FASTAPI (UNIBOOKS UDEC)
# Optimizado para Render / Google Cloud Run / Docker Compose
# ==============================================================================

FROM python:3.13-slim

WORKDIR /app

# Variables de entorno de Python
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# Instalar dependencias del sistema requeridas para compilación de psycopg2
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar dependencias e instalarlas
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código fuente
COPY . .

# Exponer puerto de la API REST
EXPOSE 8000

# Comando de arranque con uvicorn respetando la variable $PORT de Render/Cloud Run
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
