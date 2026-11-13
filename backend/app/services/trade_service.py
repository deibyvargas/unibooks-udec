from typing import List
from datetime import datetime, timezone
from sqlalchemy.orm import Session, joinedload
from fastapi import HTTPException, status
from app.models.entities import SolicitudIntercambio, Publicacion, Usuario, Notificacion
from app.core.concurrency import lock_row, compare_and_set, commit_or_conflict, raise_conflict
from app.schemas.schemas import SolicitudIntercambioCreate, SolicitudIntercambioRespuesta

class TradeService:
    @staticmethod
    def propose_trade(
        db: Session,
        solicitud_in: SolicitudIntercambioCreate,
        current_user: Usuario
    ) -> SolicitudIntercambio:
        pub_solicitada = db.query(Publicacion).filter(Publicacion.id == solicitud_in.publicacion_solicitada_id).first()
        if not pub_solicitada:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="El libro solicitado no existe")

        if pub_solicitada.usuario_id == current_user.id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No puedes proponerte un trueque a ti mismo")

        if pub_solicitada.estado != "DISPONIBLE":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El libro solicitado no está disponible para intercambio")

        if solicitud_in.publicacion_ofrecida_id:
            pub_ofrecida = db.query(Publicacion).filter(Publicacion.id == solicitud_in.publicacion_ofrecida_id).first()
            if (
                not pub_ofrecida
                or pub_ofrecida.usuario_id != current_user.id
                or pub_ofrecida.estado != "DISPONIBLE"
            ):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El libro ofrecido debe pertenecer a tu catálogo")

        nueva_solicitud = SolicitudIntercambio(
            publicacion_solicitada_id=solicitud_in.publicacion_solicitada_id,
            publicacion_ofrecida_id=solicitud_in.publicacion_ofrecida_id,
            usuario_solicitante_id=current_user.id,
            usuario_receptor_id=pub_solicitada.usuario_id,
            mensaje_propuesta=solicitud_in.mensaje_propuesta,
            estado="PENDIENTE"
        )
        db.add(nueva_solicitud)
        db.flush()

        # Notificar al dueño del libro
        notif = Notificacion(
            usuario_id=pub_solicitada.usuario_id,
            tipo="OFERTA_INTERCAMBIO",
            titulo="Nueva propuesta de intercambio",
            mensaje=f"{current_user.nombre_completo} te ha propuesto un trueque por tu libro '{pub_solicitada.titulo}'.",
            referencia_id=nueva_solicitud.id,
            tipo_referencia="solicitudes_intercambio"
        )
        db.add(notif)
        commit_or_conflict(db)
        db.refresh(nueva_solicitud)
        return nueva_solicitud

    @staticmethod
    def get_received(db: Session, current_user: Usuario) -> List[SolicitudIntercambio]:
        return db.query(SolicitudIntercambio).options(
            joinedload(SolicitudIntercambio.publicacion_solicitada),
            joinedload(SolicitudIntercambio.publicacion_ofrecida),
            joinedload(SolicitudIntercambio.usuario_solicitante)
        ).filter(
            SolicitudIntercambio.usuario_receptor_id == current_user.id
        ).order_by(SolicitudIntercambio.created_at.desc()).all()

    @staticmethod
    def get_sent(db: Session, current_user: Usuario) -> List[SolicitudIntercambio]:
        return db.query(SolicitudIntercambio).options(
            joinedload(SolicitudIntercambio.publicacion_solicitada),
            joinedload(SolicitudIntercambio.publicacion_ofrecida)
        ).filter(
            SolicitudIntercambio.usuario_solicitante_id == current_user.id
        ).order_by(SolicitudIntercambio.created_at.desc()).all()

    @staticmethod
    def respond(
        db: Session,
        solicitud_id: str,
        respuesta: SolicitudIntercambioRespuesta,
        current_user: Usuario
    ) -> SolicitudIntercambio:
        solicitud = lock_row(db.query(SolicitudIntercambio).filter(SolicitudIntercambio.id == solicitud_id))
        if not solicitud:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Propuesta no encontrada")

        if solicitud.usuario_receptor_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No autorizado para responder a esta propuesta")

        if solicitud.estado != "PENDIENTE":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"La propuesta ya fue respondida con estado {solicitud.estado}")

        valores = {"fecha_respuesta": datetime.now(timezone.utc)}
        if respuesta.aceptar:
            valores["estado"] = "ACEPTADA"
            notif = Notificacion(
                usuario_id=solicitud.usuario_solicitante_id,
                tipo="RESPUESTA_INTERCAMBIO",
                titulo="¡Propuesta de trueque aceptada!",
                mensaje=f"{current_user.nombre_completo} ha aceptado tu propuesta de trueque.",
                referencia_id=solicitud.id,
                tipo_referencia="solicitudes_intercambio"
            )
        else:
            valores["estado"] = "RECHAZADA"
            valores["motivo_rechazo"] = respuesta.motivo_rechazo
            notif = Notificacion(
                usuario_id=solicitud.usuario_solicitante_id,
                tipo="RESPUESTA_INTERCAMBIO",
                titulo="Propuesta de trueque declinada",
                mensaje=f"{current_user.nombre_completo} ha declinado tu propuesta de trueque.",
                referencia_id=solicitud.id,
                tipo_referencia="solicitudes_intercambio"
            )

        # Transición condicional PENDIENTE -> ACEPTADA/RECHAZADA (una sola respuesta gana)
        if not compare_and_set(db, SolicitudIntercambio, solicitud.id, {"estado": "PENDIENTE"}, valores):
            raise_conflict(db, "La propuesta ya fue respondida por otra petición")

        db.add(notif)
        commit_or_conflict(db)
        db.refresh(solicitud)
        return solicitud
