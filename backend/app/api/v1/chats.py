import os
import uuid
import shutil
from typing import List, Optional
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Request
from sqlalchemy.orm import Session, joinedload
from app.api.deps import get_db, get_current_user
from app.models.entities import Conversacion, Mensaje, Usuario, Notificacion, Publicacion
from app.schemas.schemas import ConversacionOut, MensajeOut, MensajeCreate

router = APIRouter(prefix="/chats", tags=["Notificaciones y Mensajería / Contacto"])


def _format_conversacion(c: Conversacion, current_user_id: str, db: Session) -> ConversacionOut:
    """Enriquece los datos de la conversación con detalles del interlocutor y del libro negociado."""
    otro_usuario = c.usuario_dos if c.usuario_uno_id == current_user_id else c.usuario_uno
    unread_count = db.query(Mensaje).filter(
        Mensaje.conversacion_id == c.id,
        Mensaje.remitente_id != current_user_id,
        Mensaje.leido == False
    ).count()

    portada_url = None
    if c.publicacion:
        if c.publicacion.fotos and len(c.publicacion.fotos) > 0:
            portada_url = c.publicacion.fotos[0].foto_url

    sede_nombre = None
    if otro_usuario and otro_usuario.sede_principal:
        sede_nombre = otro_usuario.sede_principal.nombre

    # Determinar tipo de último mensaje
    ultimo_tipo = "TEXT"
    ultimo_msg = db.query(Mensaje).filter(Mensaje.conversacion_id == c.id).order_by(Mensaje.created_at.desc()).first()
    if ultimo_msg and ultimo_msg.tipo:
        ultimo_tipo = ultimo_msg.tipo

    return ConversacionOut(
        id=c.id,
        publicacion_id=c.publicacion_id,
        publicacion_titulo=c.publicacion.titulo if c.publicacion else "Consulta General",
        publicacion_portada_url=portada_url,
        publicacion_precio=float(c.publicacion.precio) if c.publicacion and c.publicacion.precio is not None else None,
        publicacion_modalidad=c.publicacion.modalidad if c.publicacion else None,
        usuario_uno_id=c.usuario_uno_id,
        usuario_dos_id=c.usuario_dos_id,
        otro_usuario_id=otro_usuario.id if otro_usuario else None,
        otro_usuario_nombre=otro_usuario.nombre_completo if otro_usuario else "Compañero UDEC",
        otro_usuario_avatar_url=otro_usuario.avatar_url if otro_usuario else None,
        otro_usuario_email=otro_usuario.email if otro_usuario else None,
        otro_usuario_sede=sede_nombre,
        mensajes_no_leidos=unread_count,
        ultimo_mensaje_texto=c.ultimo_mensaje_texto or "Conversación iniciada",
        ultimo_mensaje_tipo=ultimo_tipo,
        ultimo_mensaje_at=c.ultimo_mensaje_at or c.created_at,
        created_at=c.created_at
    )


@router.get("/conversaciones", response_model=List[ConversacionOut], summary="Listar conversaciones activas del usuario")
def get_conversaciones(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retorna la bandeja de entrada de conversaciones (estilo WhatsApp) enriquecida con metadatos del libro e interlocutor."""
    conversaciones = db.query(Conversacion).options(
        joinedload(Conversacion.publicacion).joinedload(Publicacion.fotos),
        joinedload(Conversacion.usuario_uno).joinedload(Usuario.sede_principal),
        joinedload(Conversacion.usuario_dos).joinedload(Usuario.sede_principal)
    ).filter(
        (Conversacion.usuario_uno_id == current_user.id) | (Conversacion.usuario_dos_id == current_user.id)
    ).order_by(Conversacion.ultimo_mensaje_at.desc()).all()

    return [_format_conversacion(c, current_user.id, db) for c in conversaciones]


@router.post("/iniciar", response_model=ConversacionOut, summary="Iniciar o recuperar chat respecto a una publicación")
def iniciar_conversacion(
    destinatario_id: str,
    publicacion_id: Optional[str] = None,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Inicia una conversación directa entre dos estudiantes vinculada a un libro específico de interés."""
    if destinatario_id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No puedes iniciar un chat contigo mismo")

    destinatario = db.query(Usuario).filter(Usuario.id == destinatario_id).first()
    if not destinatario:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario destinatario no encontrado")

    # Buscar conversación existente
    query = db.query(Conversacion).filter(
        (
            ((Conversacion.usuario_uno_id == current_user.id) & (Conversacion.usuario_dos_id == destinatario_id)) |
            ((Conversacion.usuario_uno_id == destinatario_id) & (Conversacion.usuario_dos_id == current_user.id))
        )
    )
    if publicacion_id:
        query = query.filter(Conversacion.publicacion_id == publicacion_id)

    conversacion = query.first()

    if not conversacion:
        conversacion = Conversacion(
            publicacion_id=publicacion_id,
            usuario_uno_id=current_user.id,
            usuario_dos_id=destinatario_id,
            ultimo_mensaje_texto="Conversación iniciada"
        )
        db.add(conversacion)
        db.commit()
        db.refresh(conversacion)

    # Recargar con relaciones
    conversacion = db.query(Conversacion).options(
        joinedload(Conversacion.publicacion).joinedload(Publicacion.fotos),
        joinedload(Conversacion.usuario_uno).joinedload(Usuario.sede_principal),
        joinedload(Conversacion.usuario_dos).joinedload(Usuario.sede_principal)
    ).filter(Conversacion.id == conversacion.id).first()

    return _format_conversacion(conversacion, current_user.id, db)


@router.get("/conversaciones/{conversacion_id}/mensajes", response_model=List[MensajeOut], summary="Ver mensajes de una conversación")
def get_mensajes(
    conversacion_id: str,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Consulta el historial de mensajes de un chat y marca como leídos los mensajes recibidos."""
    conversacion = db.query(Conversacion).filter(Conversacion.id == conversacion_id).first()
    if not conversacion:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversación no encontrada")

    if conversacion.usuario_uno_id != current_user.id and conversacion.usuario_dos_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No tienes acceso a esta conversación")

    # Marcar mensajes recibidos como leídos
    db.query(Mensaje).filter(
        Mensaje.conversacion_id == conversacion_id,
        Mensaje.remitente_id != current_user.id,
        Mensaje.leido == False
    ).update({"leido": True})
    db.commit()

    return db.query(Mensaje).filter(
        Mensaje.conversacion_id == conversacion_id
    ).order_by(Mensaje.created_at.asc()).all()


@router.post("/conversaciones/{conversacion_id}/mensajes", response_model=MensajeOut, status_code=status.HTTP_201_CREATED, summary="Enviar un mensaje de texto o foto")
def enviar_mensaje(
    conversacion_id: str,
    mensaje_in: MensajeCreate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Envía un mensaje en el chat (soporta texto plano o fotografías adjuntas)."""
    conversacion = db.query(Conversacion).filter(Conversacion.id == conversacion_id).first()
    if not conversacion:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversación no encontrada")

    if conversacion.usuario_uno_id != current_user.id and conversacion.usuario_dos_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No tienes acceso a esta conversación")

    contenido_texto = mensaje_in.contenido or ""
    if mensaje_in.tipo == "IMAGE" and not contenido_texto:
        contenido_texto = "📷 Fotografía compartida"

    if not contenido_texto and not mensaje_in.foto_url:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El mensaje no puede estar vacío")

    nuevo_mensaje = Mensaje(
        conversacion_id=conversacion_id,
        remitente_id=current_user.id,
        contenido=contenido_texto,
        tipo=mensaje_in.tipo or "TEXT",
        foto_url=mensaje_in.foto_url
    )
    conversacion.ultimo_mensaje_texto = contenido_texto
    conversacion.ultimo_mensaje_at = datetime.now(timezone.utc)

    db.add(nuevo_mensaje)
    db.flush()

    destinatario_id = conversacion.usuario_dos_id if current_user.id == conversacion.usuario_uno_id else conversacion.usuario_uno_id
    notif = Notificacion(
        usuario_id=destinatario_id,
        tipo="MENSAJE_NUEVO",
        titulo="Nuevo mensaje de contacto",
        mensaje=f"{current_user.nombre_completo}: {contenido_texto[:60]}",
        referencia_id=conversacion.id,
        tipo_referencia="conversaciones"
    )
    db.add(notif)
    db.commit()
    db.refresh(nuevo_mensaje)

    return nuevo_mensaje


@router.post("/upload-media", summary="Subir imagen multimedia para el chat o publicaciones")
async def upload_chat_media(
    request: Request,
    file: UploadFile = File(...),
    storage_path: Optional[str] = Form(None),
    current_user: Usuario = Depends(get_current_user)
):
    """Recibe y almacena un archivo fotográfico (JPEG, PNG, WebP) generando una URL accesible."""
    content_type = (file.content_type or "").lower()
    ext = os.path.splitext(file.filename or "")[1].lower()
    valid_exts = [".jpg", ".jpeg", ".png", ".webp"]

    # Permitir tanto mimetype image/* como uploads octet-stream con extensiones o firmas de imagen
    is_image = content_type.startswith("image/") or ext in valid_exts or content_type == "application/octet-stream"
    if not is_image:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El archivo debe ser una imagen válida (JPEG, PNG, WebP)")

    if ext not in valid_exts:
        ext = ".jpg"

    file_id = f"media_{uuid.uuid4().hex[:12]}{ext}"
    static_media_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "static", "media")
    os.makedirs(static_media_dir, exist_ok=True)
    file_path = os.path.join(static_media_dir, file_id)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    base = str(request.base_url).rstrip('/')
    full_url = f"{base}/static/media/{file_id}"

    return {
        "filename": file_id,
        "storage_path": storage_path,
        "url": full_url,
        "full_url": full_url
    }

