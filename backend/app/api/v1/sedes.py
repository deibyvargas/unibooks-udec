from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.api.deps import get_db
from app.models.entities import Sede, Facultad, ProgramaAcademico, PuntoEncuentro
from app.schemas.schemas import SedeOut, FacultadOut, ProgramaAcademicoOut, PuntoEncuentroOut

router = APIRouter(prefix="/institucional", tags=["Información Institucional UDEC"])

@router.get("/sedes", response_model=List[SedeOut], summary="Listar sedes y seccionales de la UDEC")
def list_sedes(db: Session = Depends(get_db)):
    """Retorna las sedes (Fusagasugá, Girardot, Ubaté, Facatativá, Chía, Soacha, Chocontá, Zipaquirá)."""
    return db.query(Sede).filter(Sede.activo == True).order_by(Sede.nombre).all()

@router.get("/facultades", response_model=List[FacultadOut], summary="Listar facultades académicas")
def list_facultades(db: Session = Depends(get_db)):
    """Retorna las facultades de la Universidad de Cundinamarca."""
    return db.query(Facultad).filter(Facultad.activo == True).order_by(Facultad.nombre).all()

@router.get("/programas", response_model=List[ProgramaAcademicoOut], summary="Listar programas académicos")
def list_programas(
    facultad_id: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Retorna programas académicos (carreras), filtrables opcionalmente por facultad."""
    query = db.query(ProgramaAcademico).filter(ProgramaAcademico.activo == True)
    if facultad_id:
        query = query.filter(ProgramaAcademico.facultad_id == facultad_id)
    return query.order_by(ProgramaAcademico.nombre).all()

@router.get("/sedes/{sede_id}/puntos-encuentro", response_model=List[PuntoEncuentroOut], summary="Listar puntos seguros de entrega por sede")
def list_puntos_encuentro(sede_id: str, db: Session = Depends(get_db)):
    """Retorna los puntos de encuentro seguros y vigilados dentro del campus de una sede."""
    return db.query(PuntoEncuentro).filter(
        PuntoEncuentro.sede_id == sede_id,
        PuntoEncuentro.activo == True
    ).order_by(PuntoEncuentro.nombre).all()
