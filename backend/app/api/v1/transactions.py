import random
from typing import List
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from app.api.deps import get_db, get_current_user
from app.models.entities import Transaccion, Publicacion, PuntoEncuentro, Usuario, Notificacion, SolicitudIntercambio, EvaluacionEntrega
from app.schemas.schemas import TransaccionCreate, TransaccionConfirmacionEntrega, TransaccionOut, TransaccionRespuesta, EvaluacionEntregaOut

router = APIRouter(prefix="/transacciones", tags=["Módulo de Reserva, Compra y Punto de Encuentro"])

def generate_pin() -> str:
    """Genera un PIN de seguridad numérico aleatorio de 4 dígitos para validar la entrega en el campus."""
    return f"{random.randint(1000, 9999)}"

def _filter_pin_visibility(transaccion: Transaccion, user_id: str, is_admin: bool = False) -> Transaccion:
    """
    El usuario SOLICITANTE (comprador_id) es el ÚNICO que puede visualizar el PIN.
    El usuario ENTREGADOR (vendedor_id) NO debe tener acceso visual al PIN ni recibirlo expuesto.
    """
    if not is_admin and transaccion.comprador_id != user_id:
        transaccion.codigo_verificacion_entrega = ""
    return transaccion

@router.post("/reservar", response_model=TransaccionOut, status_code=status.HTTP_201_CREATED, summary="Reservar libro y agendar punto de encuentro")
def reservar_libro(
    transaccion_in: TransaccionCreate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Inicia el proceso de compra, donación o entrega de trueque en un punto físico seguro de la UDEC.
    Genera un PIN de seguridad antifraude de 4 dígitos para el solicitante.
    """
    publicacion = db.query(Publicacion).filter(Publicacion.id == transaccion_in.publicacion_id).first()
    if not publicacion:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Publicación no encontrada")

    if publicacion.usuario_id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No puedes reservar tu propia publicación")

    if publicacion.estado != "DISPONIBLE":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"El libro ya se encuentra en estado '{publicacion.estado}'")

    punto = db.query(PuntoEncuentro).filter(PuntoEncuentro.id == transaccion_in.punto_encuentro_id).first()
    if not punto:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Punto de encuentro no válido")

    nueva_transaccion = Transaccion(
        publicacion_id=publicacion.id,
        solicitud_intercambio_id=transaccion_in.solicitud_intercambio_id,
        vendedor_id=publicacion.usuario_id,
        comprador_id=current_user.id,
        tipo_transaccion=transaccion_in.tipo_transaccion,
        monto_pago=transaccion_in.monto_pago,
        punto_encuentro_id=punto.id,
        fecha_hora_encuentro=transaccion_in.fecha_hora_encuentro,
        codigo_verificacion_entrega="",
        estado="SOLICITUD_PENDIENTE"
    )

    db.add(nueva_transaccion)
    db.flush()

    # Notificar al vendedor/dueño (entregador)
    notif = Notificacion(
        usuario_id=publicacion.usuario_id,
        tipo="NUEVA_RESERVA",
        titulo="Nueva solicitud para adquirir tu libro",
        mensaje=f"{current_user.nombre_completo} quiere adquirir '{publicacion.titulo}' para entrega en: {punto.nombre}.",
        referencia_id=nueva_transaccion.id,
        tipo_referencia="transacciones"
    )
    db.add(notif)
    db.commit()
    db.refresh(nueva_transaccion)

    return nueva_transaccion


@router.post("/{transaccion_id}/responder", response_model=TransaccionOut)
def responder_solicitud_adquisicion(
    transaccion_id: str,
    respuesta: TransaccionRespuesta,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    transaccion = db.query(Transaccion).filter(Transaccion.id == transaccion_id).first()
    if not transaccion:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    if transaccion.vendedor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Solo el dueño puede responder esta solicitud")
    if transaccion.estado != "SOLICITUD_PENDIENTE":
        raise HTTPException(status_code=409, detail="La solicitud ya fue respondida")

    if respuesta.aceptar:
        transaccion.estado = "PENDIENTE_ENCUENTRO"
        transaccion.codigo_verificacion_entrega = generate_pin()
        mensaje = "Tu solicitud fue aceptada. Ya puedes consultar tu PIN de entrega."
    else:
        transaccion.estado = "CANCELADA"
        mensaje = "Tu solicitud fue rechazada. El libro continúa disponible."

    db.add(Notificacion(
        usuario_id=transaccion.comprador_id,
        tipo="RESPUESTA_RESERVA",
        titulo="Respuesta a tu solicitud de adquisición",
        mensaje=mensaje,
        referencia_id=transaccion.id,
        tipo_referencia="transacciones",
    ))
    db.commit()
    db.refresh(transaccion)
    return transaccion


@router.get("/mis-transacciones", response_model=List[TransaccionOut], summary="Listar transacciones del usuario")
def get_mis_transacciones(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Retorna todas las transacciones donde el usuario participa como vendedor o comprador.
    Oculta el PIN al entregador/vendedor por seguridad.
    """
    transacciones = db.query(Transaccion).options(
        joinedload(Transaccion.publicacion),
        joinedload(Transaccion.punto_encuentro),
        joinedload(Transaccion.vendedor),
        joinedload(Transaccion.comprador)
    ).filter(
        (Transaccion.vendedor_id == current_user.id) | (Transaccion.comprador_id == current_user.id)
    ).order_by(Transaccion.created_at.desc()).all()

    is_admin = current_user.rol in ("ADMIN", "ADMINISTRADOR")
    for tx in transacciones:
        _filter_pin_visibility(tx, current_user.id, is_admin)

    return transacciones


@router.get("/{transaccion_id}", response_model=TransaccionOut, summary="Obtener detalle de una transacción")
def get_transaccion_detalle(
    transaccion_id: str,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Consulta los detalles, punto de encuentro y estado de entrega de una transacción."""
    transaccion = db.query(Transaccion).options(
        joinedload(Transaccion.publicacion),
        joinedload(Transaccion.punto_encuentro),
        joinedload(Transaccion.vendedor),
        joinedload(Transaccion.comprador)
    ).filter(Transaccion.id == transaccion_id).first()

    if not transaccion:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transacción no encontrada")

    is_admin = current_user.rol in ("ADMIN", "ADMINISTRADOR")

    if transaccion.vendedor_id != current_user.id and transaccion.comprador_id != current_user.id and not is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No autorizado para ver esta transacción")

    _filter_pin_visibility(transaccion, current_user.id, is_admin)
    return transaccion


@router.post("/{transaccion_id}/confirmar-entrega", response_model=TransaccionOut, summary="Confirmar entrega mediante código PIN en el campus")
def confirmar_entrega(
    transaccion_id: str,
    confirmacion: TransaccionConfirmacionEntrega,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Valida el código PIN al momento de encontrarse en la universidad.
    Solo el entregador (dueño del libro) puede ingresar el PIN y confirmar la entrega.
    Al confirmar, se marca como COMPLETADA, el libro como NO_DISPONIBLE y se notifica a ambos.
    """
    transaccion = db.query(Transaccion).filter(Transaccion.id == transaccion_id).first()
    if not transaccion:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transacción no encontrada")

    is_admin = current_user.rol in ("ADMIN", "ADMINISTRADOR")

    if transaccion.vendedor_id != current_user.id and not is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo el usuario entregador (dueño del libro) puede ingresar el PIN y confirmar la entrega."
        )

    if transaccion.estado != "PENDIENTE_ENCUENTRO":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La entrega solo puede confirmarse después de que el dueño apruebe la solicitud",
        )

    if transaccion.estado == "COMPLETADA":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="La transacción ya se encuentra completada")

    # Validar PIN
    if confirmacion.codigo_verificacion.strip() != transaccion.codigo_verificacion_entrega:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="PIN incorrecto, verifica con el solicitante"
        )

    # Registrar confirmación
    transaccion.confirmado_vendedor = True
    transaccion.confirmado_comprador = True
    transaccion.estado = "COMPLETADA"
    transaccion.fecha_completada = datetime.now(timezone.utc)
    transaccion.observaciones_entrega = confirmacion.observaciones

    # Actualizar estado final del libro a "NO_DISPONIBLE" para darlo de baja del catálogo
    publicacion = db.query(Publicacion).filter(Publicacion.id == transaccion.publicacion_id).first()
    if publicacion:
        publicacion.estado = "NO_DISPONIBLE"
        db.query(Transaccion).filter(
            Transaccion.publicacion_id == publicacion.id,
            Transaccion.id != transaccion.id,
            Transaccion.estado.in_(("SOLICITUD_PENDIENTE", "PENDIENTE_ENCUENTRO")),
        ).update({"estado": "CANCELADA"}, synchronize_session=False)

    for participant_id in (transaccion.vendedor_id, transaccion.comprador_id):
        if not db.query(EvaluacionEntrega).filter(
            EvaluacionEntrega.transaccion_id == transaccion.id,
            EvaluacionEntrega.evaluador_id == participant_id,
        ).first():
            db.add(EvaluacionEntrega(
                transaccion_id=transaccion.id,
                evaluador_id=participant_id,
                estado="PENDIENTE",
            ))

    db.flush()

    # Notificaciones de éxito a ambos usuarios confirmando que el libro ha sido entregado
    nombre_libro = publicacion.titulo if publicacion else "el libro"

    notif_vendedor = Notificacion(
        usuario_id=transaccion.vendedor_id,
        tipo="ENTREGA_CONFIRMADA",
        titulo="¡Entrega confirmada con éxito!",
        mensaje=f"Has completado la entrega de '{nombre_libro}' exitosamente en el punto de encuentro.",
        referencia_id=transaccion.id,
        tipo_referencia="transacciones"
    )
    notif_comprador = Notificacion(
        usuario_id=transaccion.comprador_id,
        tipo="ENTREGA_CONFIRMADA",
        titulo="¡Libro recibido con éxito!",
        mensaje=f"Has recibido '{nombre_libro}' en el punto de encuentro campus.",
        referencia_id=transaccion.id,
        tipo_referencia="transacciones"
    )
    db.add(notif_vendedor)
    db.add(notif_comprador)
    db.commit()
    db.refresh(transaccion)

    return transaccion
