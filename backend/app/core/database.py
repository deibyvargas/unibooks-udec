"""
Capa de conectividad Backend <-> Motor de base de datos (ORM SQLAlchemy 2.0).

Temas cubiertos:
  * Conectividad (ORM): engine con pool de conexiones configurable para
    PostgreSQL (psycopg2) y SQLite (desarrollo / pruebas).
  * Fundamentos de transacciones: sesiones con autocommit desactivado,
    `get_db` hace ROLLBACK automático si el endpoint falla, y el context
    manager `transaction_scope` implementa el patrón Unit of Work (ACID).
  * Control de concurrencia: nivel de aislamiento READ COMMITTED explícito
    (PostgreSQL nunca permite "lecturas sucias"), WAL + busy_timeout en SQLite
    para que lectores y escritores no se bloqueen entre sí.
  * Optimización: listeners que miden el tiempo de ejecución de cada consulta
    SQL y registran las consultas lentas (> SLOW_QUERY_MS).
"""
import logging
import time
from contextlib import contextmanager
from typing import Iterator

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from app.core.config import settings

logger = logging.getLogger("unibooks.db")

IS_SQLITE = settings.DATABASE_URL.startswith("sqlite")

# ---------------------------------------------------------------------------
# 1. CONECTIVIDAD: configuración del engine según el motor
# ---------------------------------------------------------------------------
engine_kwargs = {
    "pool_pre_ping": True,   # Verifica la conexión antes de usarla (evita conexiones muertas)
    "echo": False,
}

if IS_SQLITE:
    # SQLite: una conexión puede ser usada por distintos hilos de FastAPI.
    engine_kwargs["connect_args"] = {"check_same_thread": False, "timeout": 15}
else:
    # PostgreSQL: pool de conexiones reutilizables para múltiples usuarios simultáneos.
    engine_kwargs.update(
        pool_size=settings.DB_POOL_SIZE,
        max_overflow=settings.DB_MAX_OVERFLOW,
        pool_timeout=30,
        pool_recycle=1800,          # Recicla conexiones cada 30 min
        isolation_level="READ COMMITTED",  # Evita lecturas sucias (dirty reads)
    )

engine = create_engine(settings.DATABASE_URL, **engine_kwargs)


if IS_SQLITE:
    @event.listens_for(engine, "connect")
    def _sqlite_pragmas(dbapi_connection, _record):
        """Ajustes de concurrencia e integridad para SQLite."""
        cursor = dbapi_connection.cursor()
        try:
            cursor.execute("PRAGMA busy_timeout=15000")  # Espera si hay un bloqueo de escritura
            if ":memory:" not in settings.DATABASE_URL:
                # WAL: los lectores no bloquean al escritor y viceversa.
                cursor.execute("PRAGMA journal_mode=WAL")
        finally:
            cursor.close()


# ---------------------------------------------------------------------------
# 2. OPTIMIZACIÓN: medición del tiempo de ejecución de consultas
# ---------------------------------------------------------------------------
class QueryStats:
    """Estadísticas en memoria de las consultas ejecutadas (para diagnóstico)."""
    total_queries = 0
    total_ms = 0.0
    slow_queries: list = []
    MAX_SLOW = 50

    @classmethod
    def record(cls, statement: str, elapsed_ms: float) -> None:
        cls.total_queries += 1
        cls.total_ms += elapsed_ms
        if elapsed_ms >= settings.SLOW_QUERY_MS:
            cls.slow_queries.append({"ms": round(elapsed_ms, 2), "sql": statement[:500]})
            del cls.slow_queries[:-cls.MAX_SLOW]
            logger.warning("Consulta lenta (%.1f ms): %s", elapsed_ms, statement[:300])

    @classmethod
    def snapshot(cls) -> dict:
        avg = cls.total_ms / cls.total_queries if cls.total_queries else 0.0
        return {
            "total_consultas": cls.total_queries,
            "tiempo_total_ms": round(cls.total_ms, 2),
            "tiempo_promedio_ms": round(avg, 3),
            "umbral_lenta_ms": settings.SLOW_QUERY_MS,
            "consultas_lentas": list(cls.slow_queries),
        }


@event.listens_for(Engine, "before_cursor_execute")
def _before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    conn.info.setdefault("query_start_time", []).append(time.perf_counter())


@event.listens_for(Engine, "after_cursor_execute")
def _after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    starts = conn.info.get("query_start_time")
    if starts:
        elapsed_ms = (time.perf_counter() - starts.pop()) * 1000
        QueryStats.record(statement, elapsed_ms)


# ---------------------------------------------------------------------------
# 3. TRANSACCIONES: sesiones y Unit of Work
# ---------------------------------------------------------------------------
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """
    Dependencia para inyección de sesión de base de datos en endpoints.
    Si ocurre cualquier excepción durante la petición, se hace ROLLBACK para
    que la transacción no deje datos a medias (atomicidad).
    """
    db: Session = SessionLocal()
    try:
        yield db
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@contextmanager
def transaction_scope(db: Session) -> Iterator[Session]:
    """
    Unit of Work: todas las operaciones dentro del bloque se confirman juntas
    (COMMIT) o se deshacen juntas (ROLLBACK) si algo falla.

        with transaction_scope(db):
            db.add(a); db.add(b)
    """
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
