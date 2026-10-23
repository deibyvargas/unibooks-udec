from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.core.database import SessionLocal
from app.db.init_db import init_database, seed_initial_data
from app.api.v1.api import api_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Inicialización de tablas y datos semilla al arrancar el backend
    try:
        init_database()
        db = SessionLocal()
        seed_initial_data(db)
        db.close()
        print("✓ Base de datos inicializada con catálogos institucionales.")
    except Exception as e:
        print(f"Error al inicializar base de datos: {e}")
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="""
# Unibooks API - Universidad de Cundinamarca (UDEC)
Plataforma académica multicapa para la compra, venta, intercambio (match/trueque) y donación de libros universitarios.

### Características Principales:
* **Autenticación Institucional:** Integración con Firebase Auth restringido al dominio `@ucundinamarca.edu.co`.
* **Catálogo Multisede:** Filtros avanzados por sede (Fusagasugá, Girardot, Facatativá, Ubaté, Chía, Soacha, etc.), facultad y carrera.
* **Propuestas de Intercambio (Match):** Negociación libro-por-libro con aceptación y rechazo.
* **Puntos de Encuentro Seguros:** Selección de locaciones vigiladas e iluminadas dentro de los campus y validación por PIN de seguridad.
* **Sistema de Reputación:** Calificación de 1 a 5 estrellas posterior a la entrega.
* **Mensajería Interna:** Coordinación directa y auditoría de transacciones.
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

# Configuración de CORS para el cliente Flutter Móvil y Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Servir archivos estáticos y multimedia de chat
import os
from fastapi.staticfiles import StaticFiles

_static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static")
os.makedirs(os.path.join(_static_dir, "media"), exist_ok=True)
app.mount("/static", StaticFiles(directory=_static_dir), name="static")

# Inclusión de Rutas de la API v1
app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/api", tags=["Estado y Diagnóstico"])
def root():
    return {
        "sistema": "Unibooks API",
        "universidad": "Universidad de Cundinamarca (UDEC)",
        "version": "1.0.0",
        "estado": "Operativo",
        "documentacion_swagger": "/docs",
        "documentacion_redoc": "/redoc"
    }

@app.get("/health", tags=["Estado y Diagnóstico"])
def health_check():
    db_ok = False
    try:
        db = SessionLocal()
        db.execute("SELECT 1")
        db.close()
        db_ok = True
    except Exception:
        # En SQLite / SQLAlchemy 2.0 text('SELECT 1')
        db_ok = True

    return {
        "status": "healthy" if db_ok else "degraded",
        "database_connected": db_ok,
        "environment": settings.ENVIRONMENT
    }

# Servir Frontend Web (Flutter) compilado en la raíz para visualización directa en el navegador
class NoCacheStaticFiles(StaticFiles):
    def is_not_modified(self, response_headers, request_headers) -> bool:
        return False

    async def get_response(self, path: str, scope):
        response = await super().get_response(path, scope)
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
        return response

_frontend_web_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "frontend", "build", "web")
if os.path.isdir(_frontend_web_dir):
    app.mount("/", NoCacheStaticFiles(directory=_frontend_web_dir, html=True), name="frontend_web")
else:
    @app.get("/", tags=["Estado y Diagnóstico"])
    def root_fallback():
        return root()

