from typing import List
from decimal import Decimal
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from fastapi import HTTPException, status
from app.models.entities import Calificacion, Transaccion, Usuario, Notificacion, EvaluacionEntrega
from app.schemas.schemas import CalificacionCreate

class RatingService:
    @staticmethod
    def create_rating(
        db: Session,
        calificacion_in: CalificacionCreate,
        current_user: Usuario
    ) -> Calificacion:
        transaccion = db.query(Transaccion).filter(Transaccion.id == calificacion_in.transaccion_id).first()
        if not transaccion:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transacción no encontrada")

        if transaccion.estado != "COMPLETADA":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Solo es posible calificar transacciones con estado 'COMPLETADA'"
            )

        evaluacion = db.query(EvaluacionEntrega).filter(
            EvaluacionEntrega.transaccion_id == transaccion.id,
            EvaluacionEntrega.evaluador_id == current_user.id,
        ).first()
        if evaluacion and evaluacion.estado != "PENDIENTE":
            raise HTTPException(status_code=400, detail="Esta entrega ya fue evaluada u omitida")

        if current_user.id == transaccion.vendedor_id:
            evaluado_id = transaccion.comprador_id
        elif current_user.id == transaccion.comprador_id:
            evaluado_id = transaccion.vendedor_id
        else:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No eres participante de esta transacción")

        existente = db.query(Calificacion).filter(
            Calificacion.transaccion_id == transaccion.id,
            Calificacion.evaluador_id == current_user.id
        ).first()
        if existente:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Ya has calificado esta transacción")

        nueva_calificacion = Calificacion(
            transaccion_id=transaccion.id,
            evaluador_id=current_user.id,
            evaluado_id=evaluado_id,
            puntuacion=calificacion_in.puntuacion,
            comentario=calificacion_in.comentario,
            puntualidad=calificacion_in.puntualidad,
            estado_libro_fiel=calificacion_in.estado_libro_fiel
        )
        db.add(nueva_calificacion)
        db.flush()
        if evaluacion:
            evaluacion.estado = "COMPLETADA"
            evaluacion.calificacion_id = nueva_calificacion.id

        # Recalcular reputación atómicamente
        avg_score = db.query(func.avg(Calificacion.puntuacion)).filter(Calificacion.evaluado_id == evaluado_id).scalar()
        total_reviews = db.query(func.count(Calificacion.id)).filter(Calificacion.evaluado_id == evaluado_id).scalar()

        usuario_evaluado = db.query(Usuario).filter(Usuario.id == evaluado_id).first()
        if usuario_evaluado:
            usuario_evaluado.reputacion_promedio = Decimal(
                str(round(float(avg_score), 1) if avg_score is not None else 0.0)
            )
            usuario_evaluado.total_calificaciones = int(total_reviews)

        notif = Notificacion(
            usuario_id=evaluado_id,
            tipo="NUEVA_CALIFICACION",
            titulo="Nueva calificación recibida",
            mensaje=f"{current_user.nombre_completo} te ha calificado con {calificacion_in.puntuacion} estrellas.",
            referencia_id=nueva_calificacion.id,
            tipo_referencia="calificaciones"
        )
        db.add(notif)
        db.commit()
        db.refresh(nueva_calificacion)
        return nueva_calificacion

    @staticmethod
    def skip_rating(db: Session, transaction_id: str, current_user: Usuario) -> None:
        evaluation = db.query(EvaluacionEntrega).filter(
            EvaluacionEntrega.transaccion_id == transaction_id,
            EvaluacionEntrega.evaluador_id == current_user.id,
        ).first()
        if not evaluation:
            raise HTTPException(status_code=404, detail="Evaluación de entrega no encontrada")
        if evaluation.estado != "PENDIENTE":
            raise HTTPException(status_code=400, detail="Esta entrega ya fue evaluada u omitida")
        evaluation.estado = "OMITIDA"
        db.commit()

    @staticmethod
    def get_by_user(db: Session, usuario_id: str) -> List[Calificacion]:
        return db.query(Calificacion).options(
            joinedload(Calificacion.evaluador)
        ).filter(
            Calificacion.evaluado_id == usuario_id
        ).order_by(Calificacion.created_at.desc()).all()
