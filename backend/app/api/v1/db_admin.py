"""
Diagnóstico de base de datos (solo ADMINISTRADOR).

Expone en tiempo real:
  * Tiempos de ejecución de las consultas SQL y las consultas lentas.
  * Plan de ejecución (EXPLAIN / EXPLAIN ANALYZE) de la consulta del catálogo,
    para comprobar que el motor usa los índices.
  * Índices existentes, nivel de aislamiento y estado del pool de conexiones.
"""
import time

from fastapi import APIRouter, Depends
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from app.api.deps import get_db, require_admin
from app.core.database import engine, QueryStats, IS_SQLITE
from app.models.entities import Usuario

router = APIRouter(prefix="/admin/base-datos", tags=["Diagnóstico de Base de Datos (Administrador)"])

CATALOGO_SQL = (
    "SELECT id, titulo, precio, created_at FROM publicaciones "
    "WHERE estado = 'DISPONIBLE' AND sede_id = :sede "
    "ORDER BY created_at DESC LIMIT 20"
)


@router.get("/rendimiento", summary="Tiempos de consultas, índices y configuración de concurrencia")
def rendimiento_base_datos(
    admin: Usuario = Depends(require_admin),
    db: Session = Depends(get_db),
):
    inspector = inspect(engine)
    indices = {}
    for tabla in inspector.get_table_names():
        indices[tabla] = [
            {"nombre": ix["name"], "columnas": ix["column_names"], "unico": bool(ix.get("unique"))}
            for ix in inspector.get_indexes(tabla)
        ]

    if IS_SQLITE:
        aislamiento = "SERIALIZABLE (SQLite serializa las escrituras; WAL permite lecturas concurrentes)"
        journal = db.execute(text("PRAGMA journal_mode")).scalar()
    else:
        aislamiento = db.execute(text("SHOW transaction_isolation")).scalar()
        journal = None

    return {
        "motor": engine.dialect.name,
        "nivel_aislamiento": aislamiento,
        "journal_mode": journal,
        "pool_conexiones": engine.pool.status(),
        "estadisticas_consultas": QueryStats.snapshot(),
        "indices": indices,
    }


@router.get("/plan-catalogo", summary="Plan de ejecución (EXPLAIN) de la consulta del catálogo")
def plan_consulta_catalogo(
    sede_id: str = "11111111-1111-1111-1111-111111111101",
    admin: Usuario = Depends(require_admin),
    db: Session = Depends(get_db),
):
    params = {"sede": sede_id}
    if IS_SQLITE:
        filas = db.execute(text("EXPLAIN QUERY PLAN " + CATALOGO_SQL), params).fetchall()
        plan = [str(f[-1]) for f in filas]
    else:
        filas = db.execute(text("EXPLAIN ANALYZE " + CATALOGO_SQL), params).fetchall()
        plan = [f[0] for f in filas]

    inicio = time.perf_counter()
    resultados = db.execute(text(CATALOGO_SQL), params).fetchall()
    ms = (time.perf_counter() - inicio) * 1000

    return {
        "consulta": CATALOGO_SQL,
        "plan_ejecucion": plan,
        "usa_indice": any("INDEX" in p.upper() for p in plan),
        "tiempo_ejecucion_ms": round(ms, 3),
        "filas": len(resultados),
    }
