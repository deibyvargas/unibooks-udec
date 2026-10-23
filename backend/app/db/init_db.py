from sqlalchemy.orm import Session
from app.core.database import engine, Base
from app.models.entities import (
    Sede, Facultad, ProgramaAcademico, PuntoEncuentro,
)

def init_database():
    """Crea las tablas en la base de datos si no existen."""
    Base.metadata.create_all(bind=engine)

def seed_initial_data(db: Session):
    """Carga únicamente catálogos institucionales requeridos por los formularios."""
    if db.query(Sede).count() > 0:
        return  # Ya fue sembrada

    # 1. Sedes
    sedes_data = [
        ("11111111-1111-1111-1111-111111111101", "Sede Fusagasugá (Principal)", "Fusagasugá", "Diagonal 18 No. 20-29"),
        ("11111111-1111-1111-1111-111111111102", "Seccional Girardot", "Girardot", "Carrera 19 No. 24-209"),
        ("11111111-1111-1111-1111-111111111103", "Seccional Ubaté", "Ubaté", "Calle 6 No. 9-80"),
        ("11111111-1111-1111-1111-111111111104", "Extensión Facatativá", "Facatativá", "Calle 8 No. 5-80"),
        ("11111111-1111-1111-1111-111111111105", "Extensión Chía", "Chía", "Autopista Norte Km 20 Costado Occidental"),
        ("11111111-1111-1111-1111-111111111106", "Extensión Soacha", "Soacha", "Carrera 7 No. 13-35"),
        ("11111111-1111-1111-1111-111111111107", "Extensión Chocontá", "Chocontá", "Carrera 4 No. 5-30"),
        ("11111111-1111-1111-1111-111111111108", "Extensión Zipaquirá", "Zipaquirá", "Carrera 7 No. 1-35")
    ]
    for sid, nom, ciu, dire in sedes_data:
        db.add(Sede(id=sid, nombre=nom, ciudad=ciu, direccion=dire, activo=True))

    # 2. Facultades
    fac_data = [
        ("22222222-2222-2222-2222-222222222201", "Facultad de Ingeniería", "FING"),
        ("22222222-2222-2222-2222-222222222202", "Facultad de Ciencias Agropecuarias", "FCA"),
        ("22222222-2222-2222-2222-222222222203", "Facultad de Ciencias Administrativas, Económicas y Contables", "FCAEC"),
        ("22222222-2222-2222-2222-222222222204", "Facultad de Ciencias de la Salud", "FCS")
    ]
    for fid, nom, sig in fac_data:
        db.add(Facultad(id=fid, nombre=nom, sigla=sig, activo=True))

    # 3. Programas Académicos
    progs_data = [
        ("33333333-3333-3333-3333-333333333301", "22222222-2222-2222-2222-222222222201", "Ingeniería de Sistemas y Computación", "103504"),
        ("33333333-3333-3333-3333-333333333302", "22222222-2222-2222-2222-222222222201", "Ingeniería Electrónica", "10123"),
        ("33333333-3333-3333-3333-333333333305", "22222222-2222-2222-2222-222222222202", "Agronomía", "10432"),
        ("33333333-3333-3333-3333-333333333307", "22222222-2222-2222-2222-222222222203", "Administración de Empresas", "10221")
    ]
    for pid, fid, nom, snies in progs_data:
        db.add(ProgramaAcademico(id=pid, facultad_id=fid, nombre=nom, codigo_snies=snies, activo=True))

    # 4. Puntos de Encuentro
    puntos_data = [
        ("44444444-4444-4444-4444-444444444401", "11111111-1111-1111-1111-111111111101", "Biblioteca Central - Entrada Principal", "Zona iluminada con recepción y seguridad institucional permanente.", "Lobby de la Biblioteca Sede Fusagasugá"),
        ("44444444-4444-4444-4444-444444444402", "11111111-1111-1111-1111-111111111101", "Plazoleta de los Fundadores", "Espacio abierto central de alto tráfico y visibilidad estudiantil.", "Bancas frente a la cafetería central"),
        ("44444444-4444-4444-4444-444444444403", "11111111-1111-1111-1111-111111111102", "Biblioteca Seccional Girardot", "Punto seguro en el primer piso.", "Recepción de préstamos bibliotecarios")
    ]
    for p_id, s_id, nom, descr, ref in puntos_data:
        db.add(PuntoEncuentro(id=p_id, sede_id=s_id, nombre=nom, descripcion=descr, referencia_visual=ref, activo=True))

    db.commit()
