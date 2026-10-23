from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.models.entities import Usuario
from app.schemas.schemas import SolicitudIntercambioCreate, SolicitudIntercambioRespuesta, SolicitudIntercambioOut
from app.services.trade_service import TradeService

router = APIRouter(prefix="/intercambios", tags=["3. Módulo de Intercambio y Trueque (Match)"])

@router.post("", response_model=SolicitudIntercambioOut, status_code=status.HTTP_201_CREATED, summary="Proponer un intercambio de libro")
def create_solicitud_intercambio(
    solicitud_in: SolicitudIntercambioCreate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Permite enviar una propuesta libro-por-libro u oferta abierta a otro estudiante."""
    return TradeService.propose_trade(db, solicitud_in, current_user)

@router.get("/recibidas", response_model=List[SolicitudIntercambioOut], summary="Listar propuestas de intercambio recibidas")
def get_intercambios_recibidos(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Bandeja de propuestas entrantes recibidas por el usuario logueado."""
    return TradeService.get_received(db, current_user)

@router.get("/enviadas", response_model=List[SolicitudIntercambioOut], summary="Listar propuestas de intercambio enviadas")
def get_intercambios_enviados(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Bandeja de propuestas de trueque enviadas a otros estudiantes."""
    return TradeService.get_sent(db, current_user)

@router.post("/{solicitud_id}/responder", response_model=SolicitudIntercambioOut, summary="Aceptar o rechazar propuesta de intercambio")
def responder_intercambio(
    solicitud_id: str,
    respuesta: SolicitudIntercambioRespuesta,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Aceptar o rechazar la propuesta de trueque."""
    return TradeService.respond(db, solicitud_id, respuesta, current_user)
