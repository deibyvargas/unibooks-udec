import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column, String, Integer, SmallInteger, Numeric, Boolean,
    DateTime, ForeignKey, Text, Enum
)
from sqlalchemy.orm import relationship
from app.core.database import Base

def get_utc_now():
    return datetime.now(timezone.utc)

def generate_uuid():
    return str(uuid.uuid4())

# ==============================================================================
# ENUMERACIONES
# ==============================================================================
ROL_USUARIO = ("ESTUDIANTE", "DOCENTE", "ADMINISTRATIVO", "ADMIN", "ADMINISTRADOR")
ESTADO_USUARIO = ("ACTIVO", "SUSPENDIDO", "INACTIVO")
CONDICION_LIBRO = ("NUEVO", "COMO_NUEVO", "BUEN_ESTADO", "ACEPTABLE", "DESGASTADO")
MODALIDAD_PUBLICACION = ("VENTA", "INTERCAMBIO", "VENTA_O_INTERCAMBIO", "DONACION")
ESTADO_PUBLICACION = ("DISPONIBLE", "RESERVADO", "INTERCAMBIADO", "VENDIDO", "FINALIZADO", "CANCELADO")
ESTADO_INTERCAMBIO = ("PENDIENTE", "ACEPTADA", "RECHAZADA", "CANCELADA", "COMPLETADA")
TIPO_TRANSACCION = ("VENTA", "INTERCAMBIO", "DONACION")
ESTADO_TRANSACCION = (
    "PENDIENTE_ENCUENTRO",
    "CONFIRMADA_POR_VENDEDOR",
    "CONFIRMADA_POR_COMPRADOR",
    "COMPLETADA",
    "CANCELADA"
)
TIPO_NOTIFICACION = (
    "OFERTA_INTERCAMBIO",
    "RESPUESTA_INTERCAMBIO",
    "NUEVA_RESERVA",
    "CONFIRMACION_ENTREGA",
    "NUEVA_CALIFICACION",
    "MENSAJE_NUEVO",
    "SISTEMA"
)

# ==============================================================================
# TABLAS MAESTRAS INSTITUCIONALES (UDEC)
# ==============================================================================

class Sede(Base):
    __tablename__ = "sedes"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    nombre = Column(String(100), nullable=False, unique=True)
    ciudad = Column(String(100), nullable=False)
    direccion = Column(String(255), nullable=False)
    activo = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=get_utc_now)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now)

    puntos_encuentro = relationship("PuntoEncuentro", back_populates="sede", cascade="all, delete-orphan")
    usuarios = relationship("Usuario", back_populates="sede_principal")
    publicaciones = relationship("Publicacion", back_populates="sede")


class Facultad(Base):
    __tablename__ = "facultades"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    nombre = Column(String(150), nullable=False, unique=True)
    sigla = Column(String(20), nullable=True)
    activo = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=get_utc_now)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now)

    programas = relationship("ProgramaAcademico", back_populates="facultad", cascade="all, delete-orphan")
    publicaciones = relationship("Publicacion", back_populates="facultad")


class ProgramaAcademico(Base):
    __tablename__ = "programas_academicos"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    facultad_id = Column(String(36), ForeignKey("facultades.id", ondelete="RESTRICT"), nullable=False)
    nombre = Column(String(150), nullable=False)
    codigo_snies = Column(String(20), nullable=True)
    activo = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=get_utc_now)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now)

    facultad = relationship("Facultad", back_populates="programas")
    usuarios = relationship("Usuario", back_populates="programa")


class PuntoEncuentro(Base):
    __tablename__ = "puntos_encuentro"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    sede_id = Column(String(36), ForeignKey("sedes.id", ondelete="RESTRICT"), nullable=False)
    nombre = Column(String(120), nullable=False)
    descripcion = Column(Text, nullable=False)
    referencia_visual = Column(String(255), nullable=True)
    activo = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=get_utc_now)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now)

    sede = relationship("Sede", back_populates="puntos_encuentro")
    transacciones = relationship("Transaccion", back_populates="punto_encuentro")


# ==============================================================================
# GESTIÓN DE USUARIOS
# ==============================================================================

class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    firebase_uid = Column(String(128), nullable=False, unique=True, index=True)
    email = Column(String(150), nullable=False, unique=True, index=True)
    password_hash = Column(String(255), nullable=True)
    nombre_completo = Column(String(150), nullable=False)
    telefono = Column(String(20), nullable=True)
    avatar_url = Column(Text, nullable=True)
    sede_principal_id = Column(String(36), ForeignKey("sedes.id", ondelete="SET NULL"), nullable=True)
    programa_id = Column(String(36), ForeignKey("programas_academicos.id", ondelete="SET NULL"), nullable=True)
    rol = Column(String(30), nullable=False, default="ESTUDIANTE")
    estado = Column(String(30), nullable=False, default="ACTIVO")
    activo = Column(Boolean, nullable=False, default=True)
    reputacion_promedio = Column(Numeric(3, 2), nullable=False, default=5.00)
    total_calificaciones = Column(Integer, nullable=False, default=0)
    biografia = Column(String(300), nullable=True)
    created_at = Column(DateTime, default=get_utc_now)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now)

    @property
    def foto_perfil_url(self):
        return self.avatar_url

    @foto_perfil_url.setter
    def foto_perfil_url(self, value):
        self.avatar_url = value

    @property
    def sede(self):
        return self.sede_principal.nombre if self.sede_principal else None

    @property
    def carrera(self):
        return self.programa.nombre if self.programa else None

    sede_principal = relationship("Sede", back_populates="usuarios")
    programa = relationship("ProgramaAcademico", back_populates="usuarios")
    publicaciones = relationship("Publicacion", back_populates="usuario", cascade="all, delete-orphan")
    solicitudes_enviadas = relationship(
        "SolicitudIntercambio",
        foreign_keys="SolicitudIntercambio.usuario_solicitante_id",
        back_populates="usuario_solicitante",
        cascade="all, delete-orphan"
    )
    solicitudes_recibidas = relationship(
        "SolicitudIntercambio",
        foreign_keys="SolicitudIntercambio.usuario_receptor_id",
        back_populates="usuario_receptor",
        cascade="all, delete-orphan"
    )
    notificaciones = relationship("Notificacion", back_populates="usuario", cascade="all, delete-orphan")


# ==============================================================================
# CATÁLOGO DE LIBROS Y PUBLICACIONES
# ==============================================================================

class Publicacion(Base):
    __tablename__ = "publicaciones"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    usuario_id = Column(String(36), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False, index=True)
    titulo = Column(String(200), nullable=False, index=True)
    autor = Column(String(150), nullable=False, index=True)
    editorial = Column(String(100), nullable=True)
    edicion = Column(String(50), nullable=True)
    ano_publicacion = Column(Integer, nullable=True)
    isbn = Column(String(20), nullable=True)
    materia = Column(String(150), nullable=True, index=True)
    semestre_sugerido = Column(SmallInteger, nullable=True)
    facultad_id = Column(String(36), ForeignKey("facultades.id", ondelete="SET NULL"), nullable=True, index=True)
    sede_id = Column(String(36), ForeignKey("sedes.id", ondelete="RESTRICT"), nullable=False, index=True)
    condicion_libro = Column(String(30), nullable=False, default="BUEN_ESTADO")
    modalidad = Column(String(30), nullable=False, default="VENTA_O_INTERCAMBIO", index=True)
    precio = Column(Numeric(10, 2), nullable=False, default=0.00)
    descripcion = Column(Text, nullable=False)
    interes_intercambio = Column(Text, nullable=True)
    estado = Column(String(30), nullable=False, default="DISPONIBLE", index=True)
    vistas = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=get_utc_now)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now)

    usuario = relationship("Usuario", back_populates="publicaciones")
    facultad = relationship("Facultad", back_populates="publicaciones")
    sede = relationship("Sede", back_populates="publicaciones")
    fotos = relationship("FotoPublicacion", back_populates="publicacion", cascade="all, delete-orphan", order_by="FotoPublicacion.orden")
    transacciones = relationship("Transaccion", back_populates="publicacion")


class FotoPublicacion(Base):
    __tablename__ = "fotos_publicacion"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    publicacion_id = Column(String(36), ForeignKey("publicaciones.id", ondelete="CASCADE"), nullable=False, index=True)
    foto_url = Column(Text, nullable=False)
    es_portada = Column(Boolean, nullable=False, default=False)
    orden = Column(SmallInteger, nullable=False, default=0)
    created_at = Column(DateTime, default=get_utc_now)

    publicacion = relationship("Publicacion", back_populates="fotos")


# ==============================================================================
# PROPUESTAS DE INTERCAMBIO (TRUEQUE)
# ==============================================================================

class SolicitudIntercambio(Base):
    __tablename__ = "solicitudes_intercambio"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    publicacion_solicitada_id = Column(String(36), ForeignKey("publicaciones.id", ondelete="CASCADE"), nullable=False)
    publicacion_ofrecida_id = Column(String(36), ForeignKey("publicaciones.id", ondelete="SET NULL"), nullable=True)
    usuario_solicitante_id = Column(String(36), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    usuario_receptor_id = Column(String(36), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    mensaje_propuesta = Column(Text, nullable=False)
    estado = Column(String(30), nullable=False, default="PENDIENTE")
    fecha_respuesta = Column(DateTime, nullable=True)
    motivo_rechazo = Column(Text, nullable=True)
    created_at = Column(DateTime, default=get_utc_now)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now)

    publicacion_solicitada = relationship("Publicacion", foreign_keys=[publicacion_solicitada_id])
    publicacion_ofrecida = relationship("Publicacion", foreign_keys=[publicacion_ofrecida_id])
    usuario_solicitante = relationship("Usuario", foreign_keys=[usuario_solicitante_id], back_populates="solicitudes_enviadas")
    usuario_receptor = relationship("Usuario", foreign_keys=[usuario_receptor_id], back_populates="solicitudes_recibidas")
    transaccion = relationship("Transaccion", back_populates="solicitud_intercambio", uselist=False)


# ==============================================================================
# TRANSACCIONES Y RESERVAS
# ==============================================================================

class Transaccion(Base):
    __tablename__ = "transacciones"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    publicacion_id = Column(String(36), ForeignKey("publicaciones.id", ondelete="RESTRICT"), nullable=False)
    solicitud_intercambio_id = Column(String(36), ForeignKey("solicitudes_intercambio.id", ondelete="SET NULL"), nullable=True)
    vendedor_id = Column(String(36), ForeignKey("usuarios.id", ondelete="RESTRICT"), nullable=False)
    comprador_id = Column(String(36), ForeignKey("usuarios.id", ondelete="RESTRICT"), nullable=False)
    tipo_transaccion = Column(String(30), nullable=False)
    monto_pago = Column(Numeric(10, 2), nullable=False, default=0.00)
    punto_encuentro_id = Column(String(36), ForeignKey("puntos_encuentro.id", ondelete="RESTRICT"), nullable=False)
    fecha_hora_encuentro = Column(DateTime, nullable=False)
    codigo_verificacion_entrega = Column(String(6), nullable=False)
    estado = Column(String(35), nullable=False, default="PENDIENTE_ENCUENTRO")
    confirmado_vendedor = Column(Boolean, nullable=False, default=False)
    confirmado_comprador = Column(Boolean, nullable=False, default=False)
    observaciones_entrega = Column(Text, nullable=True)
    fecha_completada = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=get_utc_now)
    updated_at = Column(DateTime, default=get_utc_now, onupdate=get_utc_now)

    publicacion = relationship("Publicacion", back_populates="transacciones")
    solicitud_intercambio = relationship("SolicitudIntercambio", back_populates="transaccion")
    vendedor = relationship("Usuario", foreign_keys=[vendedor_id])
    comprador = relationship("Usuario", foreign_keys=[comprador_id])
    punto_encuentro = relationship("PuntoEncuentro", back_populates="transacciones")
    calificaciones = relationship("Calificacion", back_populates="transaccion", cascade="all, delete-orphan")


# ==============================================================================
# CALIFICACIONES Y REPUTACIÓN
# ==============================================================================

class Calificacion(Base):
    __tablename__ = "calificaciones"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    transaccion_id = Column(String(36), ForeignKey("transacciones.id", ondelete="CASCADE"), nullable=False)
    evaluador_id = Column(String(36), ForeignKey("usuarios.id", ondelete="RESTRICT"), nullable=False)
    evaluado_id = Column(String(36), ForeignKey("usuarios.id", ondelete="RESTRICT"), nullable=False)
    puntuacion = Column(SmallInteger, nullable=False)
    comentario = Column(Text, nullable=True)
    puntualidad = Column(SmallInteger, nullable=True)
    estado_libro_fiel = Column(SmallInteger, nullable=True)
    created_at = Column(DateTime, default=get_utc_now)

    transaccion = relationship("Transaccion", back_populates="calificaciones")
    evaluador = relationship("Usuario", foreign_keys=[evaluador_id])
    evaluado = relationship("Usuario", foreign_keys=[evaluado_id])


# ==============================================================================
# MENSAJERÍA DIRECTA Y NOTIFICACIONES
# ==============================================================================

class Conversacion(Base):
    __tablename__ = "conversaciones"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    publicacion_id = Column(String(36), ForeignKey("publicaciones.id", ondelete="SET NULL"), nullable=True)
    usuario_uno_id = Column(String(36), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    usuario_dos_id = Column(String(36), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    ultimo_mensaje_texto = Column(Text, nullable=True)
    ultimo_mensaje_at = Column(DateTime, default=get_utc_now)
    created_at = Column(DateTime, default=get_utc_now)

    mensajes = relationship("Mensaje", back_populates="conversacion", cascade="all, delete-orphan", order_by="Mensaje.created_at")
    publicacion = relationship("Publicacion")
    usuario_uno = relationship("Usuario", foreign_keys=[usuario_uno_id])
    usuario_dos = relationship("Usuario", foreign_keys=[usuario_dos_id])


class Mensaje(Base):
    __tablename__ = "mensajes"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    conversacion_id = Column(String(36), ForeignKey("conversaciones.id", ondelete="CASCADE"), nullable=False)
    remitente_id = Column(String(36), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    contenido = Column(Text, nullable=False)
    tipo = Column(String(10), default="TEXT", nullable=False)  # TEXT o IMAGE
    foto_url = Column(Text, nullable=True)
    leido = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=get_utc_now)

    conversacion = relationship("Conversacion", back_populates="mensajes")
    remitente = relationship("Usuario")


class Notificacion(Base):
    __tablename__ = "notificaciones"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    usuario_id = Column(String(36), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    tipo = Column(String(35), nullable=False)
    titulo = Column(String(150), nullable=False)
    mensaje = Column(Text, nullable=False)
    referencia_id = Column(String(36), nullable=True)
    tipo_referencia = Column(String(50), nullable=True)
    leida = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=get_utc_now)

    usuario = relationship("Usuario", back_populates="notificaciones")
