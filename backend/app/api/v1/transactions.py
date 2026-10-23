import random
from typing import List
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from app.api.deps import get_db, get_current_user
from app.models.entities import Transaccion, Publicacion, PuntoEncuentro, Usuario, Notificacion
from app.schemas.schemas import TransaccionCreate, TransaccionConfirmacionEntrega, TransaccionOut

router = APIRouter(prefix="/transacciones", tags=["Módulo de Reserva, Compra y Punto de Encuentro"])

def generate_pin() -> str:
    """Genera un PIN de seguridad numérico de 6 dígitos para validar la entrega en el campus."""
    return f"{random.randint(100000, 999999)}"

@router.post("/reservar", response_model=TransaccionOut, status_code=status.HTTP_201_CREATED, summary="Reservar libro y agendar punto de encuentro")
def reservar_libro(
    transaccion_in: TransaccionCreate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Inicia el proceso de compra, donación o entrega de trueque en un punto físico seguro de la UDEC.
    Genera un PIN de seguridad antifraude.
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

    pin = generate_pin()

    nueva_transaccion = Transaccion(
        publicacion_id=publicacion.id,
        solicitud_intercambio_id=transaccion_in.solicitud_intercambio_id,
        vendedor_id=publicacion.usuario_id,
        comprador_id=current_user.id,
        tipo_transaccion=transaccion_in.tipo_transaccion,
        monto_pago=transaccion_in.monto_pago,
        punto_encuentro_id=punto.id,
        fecha_hora_encuentro=transaccion_in.fecha_hora_encuentro,
        codigo_verificacion_entrega=pin,
        estado="PENDIENTE_ENCUENTRO"
    )

    # Actualizar estado del libro a RESERVADO
    publicacion.estado = "RESERVADO"

    db.add(nueva_transaccion)
    db.flush()

    # Notificar al vendedor/dueño
    notif = Notificacion(
        usuario_id=publicacion.usuario_id,
        tipo="NUEVA_RESERVA",
        titulo="¡Tu libro ha sido reservado!",
        mensaje=f"{current_user.nombre_completo} ha reservado '{publicacion.titulo}' para encuentro en: {punto.nombre}.",
        referencia_id=nueva_transaccion.id,
        tipo_referencia="transacciones"
    )
    db.add(notif)
    db.commit()
    db.refresh(nueva_transaccion)

    return nueva_transaccion


@router.get("/mis-transacciones", response_model=List[TransaccionOut], summary="Listar transacciones del usuario")
def get_mis_transacciones(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retorna todas las transacciones donde el usuario participa como vendedor o comprador."""
    return db.query(Transaccion).options(
        joinedload(Transaccion.publicacion),
        joinedload(Transaccion.punto_encuentro),
        joinedload(Transaccion.vendedor),
        joinedload(Transaccion.comprador)
    ).filter(
        (Transaccion.vendedor_id == current_user.id) | (Transaccion.comprador_id == current_user.id)
    ).order_by(Transaccion.created_at.desc()).all()


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

    if transaccion.vendedor_id != current_user.id and transaccion.comprador_id != current_user.id and current_user.rol != "ADMIN":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No autorizado para ver esta transacción")

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
    Al confirmar, se marca como COMPLETADA y la publicación como VENDIDO / INTERCAMBIADO.
    """
    transaccion = db.query(Transaccion).filter(Transaccion.id == transaccion_id).first()
    if not transaccion:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transacción no encontrada")

    if transaccion.vendedor_id != current_user.id and transaccion.comprador_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No eres parte de esta transacción")

    if transaccion.estado == "COMPLETADA":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="La transacción ya se encuentra completada")

    # Validar PIN
    if confirmacion.codigo_verificacion.strip() != transaccion.codigo_verificacion_entrega:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Código PIN de verificación incorrecto")

    # Registrar confirmación
    if current_user.id == transaccion.vendedor_id:
        transaccion.confirmado_vendedor = True
    if current_user.id == transaccion.comprador_id:
        transaccion.confirmado_comprador = True

    # Si se valida con PIN correcto, se marca completada
    transaccion.estado = "COMPLETADA"
    transaccion.fecha_completada = datetime.now(timezone.utc)
    transaccion.observaciones_entrega = confirmacion.observaciones

    # Actualizar estado final del libro
    publicacion = db.query(Publicacion).filter(Publicacion.id == transaccion.publicacion_id).first()
    if publicacion:
        publicacion.estado = "INTERCAMBIADO" if transaccion.tipo_transaccion == "INTERCAMBIO" else "VENDIDO"

    # Notificar a la otra parte
    otro_usuario_id = transaccion.comprador_id if current_user.id == transaccion.vendedor_id else transaccion.vendedor_id
    notif = Notificacion(
        usuario_id=otro_usuario_id,
        tipo="CONFIRMACION_ENTREGA",
        titulo="¡Transacción completada con éxito!",
        mensaje="La entrega del libro ha sido confirmada en el punto de encuentro. ¡No olvides calificar a tu compañero!",
        referencia_id=transaccion.id,
        tipo_referencia="transacciones"
    )
    db.add(notif)
    db.commit()
    db.refresh(transaccion)

    return transaccion
