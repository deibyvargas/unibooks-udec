"""
Benchmark de optimización e indexación de consultas - Unibooks.

Uso (desde la carpeta backend):
    python scripts/benchmark_queries.py            # 20 000 publicaciones
    python scripts/benchmark_queries.py 50000      # tamaño personalizado

Crea una base SQLite TEMPORAL e independiente (no toca la base real), la llena
con datos sintéticos y compara:
  1. Tiempo de ejecución y plan (EXPLAIN QUERY PLAN) SIN índices vs CON índices.
  2. Problema N+1 (carga perezosa) vs carga anticipada con joinedload.
El reporte se imprime y se guarda en docs/resultados_benchmark.md.
"""
import os
import random
import statistics
import sys
import tempfile
import time
import uuid
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, event, text  # noqa: E402
from sqlalchemy.orm import Session, joinedload  # noqa: E402

from app.core.database import Base  # noqa: E402
from app.db.init_db import PERFORMANCE_INDEXES  # noqa: E402
from app.models.entities import Publicacion  # noqa: E402

N_PUBLICACIONES = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
N_USUARIOS = 500
REPETICIONES = 30
SEDES = [f"sede-{i}" for i in range(8)]
ESTADOS = ["DISPONIBLE"] * 6 + ["NO_DISPONIBLE", "RESERVADO"]

CONSULTAS = {
    "Catálogo por sede (filtro + orden por fecha)": (
        "SELECT id, titulo, precio FROM publicaciones "
        "WHERE estado = 'DISPONIBLE' AND sede_id = :sede ORDER BY created_at DESC LIMIT 20",
        lambda: {"sede": random.choice(SEDES)},
    ),
    "Catálogo ordenado por precio": (
        "SELECT id, titulo, precio FROM publicaciones "
        "WHERE estado = 'DISPONIBLE' ORDER BY precio ASC LIMIT 20",
        lambda: {},
    ),
    "Mis publicaciones (usuario + fecha)": (
        "SELECT id, titulo FROM publicaciones WHERE usuario_id = :u ORDER BY created_at DESC",
        lambda: {"u": f"user-{random.randrange(N_USUARIOS)}"},
    ),
    "Mis transacciones como comprador": (
        "SELECT id, estado FROM transacciones WHERE comprador_id = :u ORDER BY created_at DESC",
        lambda: {"u": f"user-{random.randrange(N_USUARIOS)}"},
    ),
    "Notificaciones no leídas": (
        "SELECT id, titulo FROM notificaciones WHERE usuario_id = :u AND leida = 0 ORDER BY created_at DESC",
        lambda: {"u": f"user-{random.randrange(N_USUARIOS)}"},
    ),
}


def poblar(engine):
    random.seed(42)
    ahora = datetime(2026, 1, 1)
    with engine.begin() as c:
        for s in SEDES:
            c.execute(text("INSERT INTO sedes (id, nombre, ciudad, direccion, activo) VALUES (:i,:i,'X','X',1)"), {"i": s})
        c.execute(
            text("INSERT INTO usuarios (id, firebase_uid, email, nombre_completo, rol, estado, activo, "
                 "reputacion_promedio, total_calificaciones) VALUES (:i,:i,:e,'U','ESTUDIANTE','ACTIVO',1,0,0)"),
            [{"i": f"user-{i}", "e": f"u{i}@ucundinamarca.edu.co"} for i in range(N_USUARIOS)],
        )
        c.execute(text("INSERT INTO puntos_encuentro (id, sede_id, nombre, descripcion, activo) VALUES ('p1','sede-0','P','P',1)"))
        pubs = []
        for i in range(N_PUBLICACIONES):
            pubs.append({
                "i": f"pub-{i}", "u": f"user-{random.randrange(N_USUARIOS)}", "t": f"Libro {i}",
                "s": random.choice(SEDES), "e": random.choice(ESTADOS),
                "p": random.randint(5, 300) * 1000, "c": ahora - timedelta(minutes=random.randrange(500000)),
            })
        c.execute(
            text("INSERT INTO publicaciones (id, usuario_id, titulo, autor, sede_id, condicion_libro, modalidad, "
                 "precio, descripcion, estado, vistas, created_at) "
                 "VALUES (:i,:u,:t,'Autor',:s,'BUEN_ESTADO','VENTA',:p,'Descripcion',:e,0,:c)"),
            pubs,
        )
        n_tx = N_PUBLICACIONES // 2
        c.execute(
            text("INSERT INTO transacciones (id, publicacion_id, vendedor_id, comprador_id, tipo_transaccion, monto_pago, "
                 "punto_encuentro_id, fecha_hora_encuentro, codigo_verificacion_entrega, estado, "
                 "confirmado_vendedor, confirmado_comprador, created_at) "
                 "VALUES (:i,:p,:v,:b,'VENTA',0,'p1',:c,'1234',:e,0,0,:c)"),
            [{"i": f"tx-{i}", "p": f"pub-{random.randrange(N_PUBLICACIONES)}", "v": f"user-{random.randrange(N_USUARIOS)}",
              "b": f"user-{random.randrange(N_USUARIOS)}", "c": ahora - timedelta(minutes=random.randrange(500000)),
              "e": random.choice(["COMPLETADA", "CANCELADA", "PENDIENTE_ENCUENTRO"])} for i in range(n_tx)],
        )
        c.execute(
            text("INSERT INTO notificaciones (id, usuario_id, tipo, titulo, mensaje, leida, created_at) "
                 "VALUES (:i,:u,'T','Titulo','Mensaje',:l,:c)"),
            [{"i": str(uuid.uuid4()), "u": f"user-{random.randrange(N_USUARIOS)}", "l": random.random() < 0.7,
              "c": ahora - timedelta(minutes=random.randrange(500000))} for _ in range(N_PUBLICACIONES * 2)],
        )


def eliminar_indices(engine):
    with engine.begin() as c:
        nombres = c.execute(text(
            "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_autoindex%'"
        )).scalars().all()
        for n in nombres:
            c.execute(text(f'DROP INDEX "{n}"'))


def crear_indices(engine):
    for tabla in Base.metadata.sorted_tables:
        for ix in tabla.indexes:
            ix.create(bind=engine, checkfirst=True)
    with engine.begin() as c:
        for ddl in PERFORMANCE_INDEXES:
            c.execute(text(ddl))
        c.execute(text("ANALYZE"))


def medir(engine):
    resultados = {}
    with engine.connect() as c:
        for nombre, (sql, params) in CONSULTAS.items():
            plan = " | ".join(str(f[-1]) for f in c.execute(text("EXPLAIN QUERY PLAN " + sql), params()).fetchall())
            tiempos = []
            for _ in range(REPETICIONES):
                p = params()
                t0 = time.perf_counter()
                c.execute(text(sql), p).fetchall()
                tiempos.append((time.perf_counter() - t0) * 1000)
            resultados[nombre] = {"ms": statistics.median(tiempos), "plan": plan}
    return resultados


def medir_n_mas_1(engine):
    contador = {"n": 0}

    def contar(*_args, **_kw):
        contador["n"] += 1

    event.listen(engine, "before_cursor_execute", contar)
    try:
        salida = {}
        for etiqueta, opciones in (("Carga perezosa (N+1)", []),
                                   ("joinedload (1 consulta)", [joinedload(Publicacion.usuario), joinedload(Publicacion.sede)])):
            contador["n"] = 0
            t0 = time.perf_counter()
            with Session(engine) as s:
                pubs = s.query(Publicacion).options(*opciones).order_by(Publicacion.created_at.desc()).limit(200).all()
                for p in pubs:
                    _ = (p.usuario.nombre_completo, p.sede.nombre)
            salida[etiqueta] = {"consultas": contador["n"], "ms": (time.perf_counter() - t0) * 1000}
        return salida
    finally:
        event.remove(engine, "before_cursor_execute", contar)


def main():
    tmp = os.path.join(tempfile.gettempdir(), f"unibooks_benchmark_{uuid.uuid4().hex[:8]}.db")
    engine = create_engine(f"sqlite:///{tmp}")
    try:
        print(f"Creando base temporal con {N_PUBLICACIONES:,} publicaciones en {tmp} ...")
        Base.metadata.create_all(engine)
        eliminar_indices(engine)
        poblar(engine)

        print("Midiendo SIN índices ...")
        sin = medir(engine)
        print("Creando índices y midiendo CON índices ...")
        crear_indices(engine)
        con = medir(engine)
        n1 = medir_n_mas_1(engine)

        lineas = [
            "# Resultados del benchmark de consultas",
            "",
            f"Generado por `backend/scripts/benchmark_queries.py` el {datetime.now():%Y-%m-%d %H:%M}.",
            f"Datos: {N_PUBLICACIONES:,} publicaciones, {N_PUBLICACIONES // 2:,} transacciones, "
            f"{N_PUBLICACIONES * 2:,} notificaciones, {N_USUARIOS} usuarios. Mediana de {REPETICIONES} ejecuciones (SQLite).",
            "",
            "## 1. Índices: tiempo de ejecución",
            "",
            "| Consulta | Sin índices (ms) | Con índices (ms) | Mejora |",
            "|---|---:|---:|---:|",
        ]
        for nombre in CONSULTAS:
            a, b = sin[nombre]["ms"], con[nombre]["ms"]
            lineas.append(f"| {nombre} | {a:.3f} | {b:.3f} | {a / b if b else 0:.1f}x |")
        lineas += ["", "## 2. Planes de ejecución (EXPLAIN QUERY PLAN)", ""]
        for nombre in CONSULTAS:
            lineas += [f"**{nombre}**", "", f"- Sin índices: `{sin[nombre]['plan']}`",
                       f"- Con índices: `{con[nombre]['plan']}`", ""]
        lineas += ["## 3. Reducción de complejidad: problema N+1", "",
                   "Cargar 200 publicaciones y mostrar su vendedor y sede:", "",
                   "| Estrategia | Consultas SQL | Tiempo (ms) |", "|---|---:|---:|"]
        for k, v in n1.items():
            lineas.append(f"| {k} | {v['consultas']} | {v['ms']:.2f} |")
        lineas.append("")

        reporte = "\n".join(lineas)
        print("\n" + reporte)
        destino = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                               "docs", "resultados_benchmark.md")
        with open(destino, "w", encoding="utf-8") as f:
            f.write(reporte)
        print(f"Reporte guardado en {destino}")
    finally:
        engine.dispose()
        for sufijo in ("", "-wal", "-shm"):
            try:
                os.remove(tmp + sufijo)
            except OSError:
                pass


if __name__ == "__main__":
    main()
