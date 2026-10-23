from typing import List, Optional
from decimal import Decimal
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.models.entities import Usuario
from app.schemas.schemas import PublicacionCreate, PublicacionUpdate, PublicacionOut
from app.services.publication_service import PublicationService

router = APIRouter(prefix="/publicaciones", tags=["2. Catálogo y Publicaciones de Libros"])

@router.get("", response_model=List[PublicacionOut], summary="Explorar catálogo de libros con filtros avanzados")
def get_publicaciones(
    q: Optional[str] = Query(None, description="Término de búsqueda (título, autor, materia, ISBN)"),
    sede_id: Optional[str] = Query(None, description="Filtrar por sede física de la UDEC"),
    facultad_id: Optional[str] = Query(None, description="Filtrar por facultad académica"),
    semestre: Optional[int] = Query(None, ge=1, le=10, description="Filtrar por semestre sugerido"),
    modalidad: Optional[str] = Query(None, description="VENTA, INTERCAMBIO, VENTA_O_INTERCAMBIO, DONACION"),
    condicion: Optional[str] = Query(None, description="NUEVO, BUEN_ESTADO, etc."),
    precio_max: Optional[Decimal] = Query(None, ge=0, description="Precio máximo en COP"),
    estado: Optional[str] = Query("DISPONIBLE", description="Estado de la publicación"),
    sort_by: Optional[str] = Query("recent", description="recent | price_asc | price_desc | views"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db)
):
    """Consulta libros disponibles con filtros multifacéticos y búsqueda textual."""
    return PublicationService.get_filtered(
        db=db,
        q=q,
        sede_id=sede_id,
        facultad_id=facultad_id,
        semestre=semestre,
        modalidad=modalidad,
        condicion=condicion,
        precio_max=precio_max,
        estado=estado,
        sort_by=sort_by,
        skip=skip,
        limit=limit
    )

@router.get("/{publicacion_id}", response_model=PublicacionOut, summary="Obtener detalle de una publicación")
def get_publicacion_detalle(
    publicacion_id: str,
    db: Session = Depends(get_db)
):
    """Retorna información completa del libro e incrementa las visualizaciones."""
    return PublicationService.get_by_id(db, publicacion_id)

@router.post("", response_model=PublicacionOut, status_code=status.HTTP_201_CREATED, summary="Crear una nueva publicación de libro")
def create_publicacion(
    pub_in: PublicacionCreate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Crea una oferta de libro en venta, trueque o donación con galería de 1 a 4 fotos."""
    return PublicationService.create(db, pub_in, current_user)

@router.put("/{publicacion_id}", response_model=PublicacionOut, summary="Actualizar una publicación")
def update_publicacion(
    publicacion_id: str,
    pub_update: PublicacionUpdate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Actualiza los datos de la publicación. Solo el autor o un administrador tienen permiso."""
    return PublicationService.update(db, publicacion_id, pub_update, current_user)

@router.delete("/{publicacion_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar una publicación")
def delete_publicacion(
    publicacion_id: str,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Elimina la publicación del catálogo institucional."""
    PublicationService.delete(db, publicacion_id, current_user)
    return None
