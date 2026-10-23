from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.models.entities import Notificacion, Usuario
from app.schemas.schemas import NotificacionOut

router = APIRouter(prefix="/notificaciones", tags=["Notificaciones del Sistema"])

@router.get("", response_model=List[NotificacionOut], summary="Listar notificaciones del usuario autenticado")
def get_notificaciones(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retorna las alertas y avisos de trueques, reservas y mensajes."""
    return db.query(Notificacion).filter(
        Notificacion.usuario_id == current_user.id
    ).order_by(Notificacion.created_at.desc()).limit(50).all()


@router.get("/no-leidas-count", summary="Conteo de notificaciones pendientes")
def get_unread_count(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retorna el número de notificaciones no leídas para insignias en la UI."""
    count = db.query(Notificacion).filter(
        Notificacion.usuario_id == current_user.id,
        Notificacion.leida == False
    ).count()
    return {"no_leidas": count}


@router.put("/{notificacion_id}/leer", summary="Marcar una notificación como leída")
def mark_as_read(
    notificacion_id: str,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Actualiza el estado de la notificación a leída."""
    notif = db.query(Notificacion).filter(
        Notificacion.id == notificacion_id,
        Notificacion.usuario_id == current_user.id
    ).first()

    if not notif:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notificación no encontrada")

    notif.leida = True
    db.commit()
    return {"ok": True}


@router.put("/leer-todas", summary="Marcar todas las notificaciones como leídas")
def mark_all_as_read(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Marca todo el historial de notificaciones como visto."""
    db.query(Notificacion).filter(
        Notificacion.usuario_id == current_user.id,
        Notificacion.leida == False
    ).update({"leida": True})
    db.commit()
    return {"ok": True}
