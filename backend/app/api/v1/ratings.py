from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.models.entities import Usuario
from app.schemas.schemas import CalificacionCreate, CalificacionOut
from app.services.rating_service import RatingService

router = APIRouter(prefix="/calificaciones", tags=["4. Sistema de Calificación y Reputación"])

@router.post("", response_model=CalificacionOut, status_code=status.HTTP_201_CREATED, summary="Calificar a un usuario tras entrega")
def crear_calificacion(
    calificacion_in: CalificacionCreate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Registra una reseña (1 a 5 estrellas) y recalcula atómicamente la reputación del evaluado."""
    return RatingService.create_rating(db, calificacion_in, current_user)

@router.get("/usuario/{usuario_id}", response_model=List[CalificacionOut], summary="Listar calificaciones y reseñas de un usuario")
def get_user_ratings(usuario_id: str, db: Session = Depends(get_db)):
    """Retorna el historial de opiniones y calificaciones institucionales de un estudiante."""
    return RatingService.get_by_user(db, usuario_id)
