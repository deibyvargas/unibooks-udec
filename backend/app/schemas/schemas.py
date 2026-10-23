from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator, ConfigDict
from typing import Optional, List, Any
from datetime import datetime
from decimal import Decimal
from app.core.config import settings

# ==============================================================================
# SCHEMAS MAESTROS (SEDES, FACULTADES, PROGRAMAS, PUNTOS)
# ==============================================================================

class SedeBase(BaseModel):
    nombre: str = Field(..., max_length=100, examples=["Sede Fusagasugá (Principal)"])
    ciudad: str = Field(..., max_length=100, examples=["Fusagasugá"])
    direccion: str = Field(..., max_length=255, examples=["Diagonal 18 No. 20-29"])
    activo: bool = True

class SedeOut(SedeBase):
    id: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class FacultadBase(BaseModel):
    nombre: str = Field(..., max_length=150, examples=["Facultad de Ingeniería"])
    sigla: Optional[str] = Field(None, max_length=20, examples=["FING"])
    activo: bool = True

class FacultadOut(FacultadBase):
    id: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class ProgramaAcademicoBase(BaseModel):
    facultad_id: str
    nombre: str = Field(..., max_length=150, examples=["Ingeniería de Sistemas y Computación"])
    codigo_snies: Optional[str] = Field(None, max_length=20, examples=["103504"])
    activo: bool = True

class ProgramaAcademicoOut(ProgramaAcademicoBase):
    id: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class PuntoEncuentroBase(BaseModel):
    sede_id: str
    nombre: str = Field(..., max_length=120, examples=["Biblioteca Central - Entrada Principal"])
    descripcion: str = Field(..., examples=["Zona iluminada con recepción y seguridad institucional permanente."])
    referencia_visual: Optional[str] = Field(None, max_length=255, examples=["Lobby de la Biblioteca"])
    activo: bool = True

class PuntoEncuentroOut(PuntoEncuentroBase):
    id: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# SCHEMAS DE USUARIO
# ==============================================================================

class UsuarioBase(BaseModel):
    email: str = Field(..., max_length=150, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$", examples=["carlos.mendoza@ucundinamarca.edu.co"])
    nombre_completo: str = Field(..., min_length=3, max_length=150, examples=["Carlos Mendoza Vargas"])
    telefono: Optional[str] = Field(None, max_length=20, examples=["3124567890"])
    avatar_url: Optional[str] = None
    sede_principal_id: Optional[str] = None
    programa_id: Optional[str] = None
    biografia: Optional[str] = Field(None, max_length=300)

    @field_validator("email")
    @classmethod
    def validate_institutional_email(cls, v: str) -> str:
        clean = v.lower().strip()
        if clean == "vargasdeiby54@gmail.com":
            return clean
        domain = settings.INSTITUTIONAL_EMAIL_DOMAIN.lower()
        if not clean.endswith(f"@{domain}"):
            raise ValueError("Debes utilizar tu correo institucional de la Universidad de Cundinamarca (@ucundinamarca.edu.co)")
        return clean

class UsuarioCreate(UsuarioBase):
    firebase_uid: str = Field(..., min_length=4, max_length=128)
    rol: Optional[str] = "ESTUDIANTE"

class UsuarioRegister(BaseModel):
    email: str = Field(..., max_length=150, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$", examples=["carlos.mendoza@ucundinamarca.edu.co"])
    password: str = Field(..., min_length=6, max_length=128)
    nombre_completo: str = Field(..., min_length=3, max_length=150)
    sede_principal_id: Optional[str] = None
    programa_id: Optional[str] = None
    telefono: Optional[str] = None

    @field_validator("email")
    @classmethod
    def validate_institutional_email(cls, v: str) -> str:
        clean = v.lower().strip()
        if clean == "vargasdeiby54@gmail.com":
            return clean
        domain = settings.INSTITUTIONAL_EMAIL_DOMAIN.lower()
        if not clean.endswith(f"@{domain}"):
            raise ValueError("Debes utilizar tu correo institucional de la Universidad de Cundinamarca (@ucundinamarca.edu.co)")
        return clean

class UsuarioLogin(BaseModel):
    email: str = Field(..., max_length=150, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    password: str

class UsuarioUpdate(BaseModel):
    nombre_completo: Optional[str] = None
    telefono: Optional[str] = None
    avatar_url: Optional[str] = None
    sede_principal_id: Optional[str] = None
    programa_id: Optional[str] = None
    biografia: Optional[str] = None

class UsuarioOut(UsuarioBase):
    id: str
    firebase_uid: str
    rol: str
    estado: str
    activo: bool = True
    foto_perfil_url: Optional[str] = None
    sede_nombre: Optional[str] = None
    programa_nombre: Optional[str] = None
    reputacion_promedio: Decimal
    total_calificaciones: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class AuthTokenOut(BaseModel):
    token: str
    access_token: Optional[str] = None
    token_type: str = "bearer"
    user: UsuarioOut
    usuario: Optional[UsuarioOut] = None

    def model_post_init(self, __context: Any) -> None:
        if self.access_token is None:
            self.access_token = self.token
        if self.usuario is None:
            self.usuario = self.user


# ==============================================================================
# SCHEMAS DE PUBLICACIONES Y FOTOS
# ==============================================================================

class FotoPublicacionBase(BaseModel):
    foto_url: str = Field(..., examples=["https://firebasestorage.googleapis.com/..."])
    es_portada: bool = False
    orden: int = 0

class FotoPublicacionOut(FotoPublicacionBase):
    id: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class PublicacionBase(BaseModel):
    titulo: str = Field(..., min_length=2, max_length=200, examples=["Cálculo: Trascendentes Tempranas"])
    autor: str = Field(..., min_length=2, max_length=150, examples=["James Stewart"])
    editorial: Optional[str] = Field(None, max_length=100, examples=["Cengage Learning"])
    edicion: Optional[str] = Field(None, max_length=50, examples=["7ma Edición"])
    ano_publicacion: Optional[int] = Field(None, ge=1800, le=2030, examples=[2015])
    isbn: Optional[str] = Field(None, max_length=20, examples=["9786074817843"])
    materia: Optional[str] = Field(None, max_length=150, examples=["Cálculo Diferencial e Integral"])
    semestre_sugerido: Optional[int] = Field(None, ge=1, le=10, examples=[2])
    facultad_id: Optional[str] = None
    sede_id: str
    condicion_libro: str = Field(default="BUEN_ESTADO", examples=["BUEN_ESTADO"])
    modalidad: str = Field(default="VENTA_O_INTERCAMBIO", examples=["VENTA_O_INTERCAMBIO"])
    precio: Decimal = Field(default=Decimal("0.00"), ge=0, examples=[65000.00])
    descripcion: str = Field(..., min_length=10, examples=["Libro en perfecto estado para cálculo de ingeniería."])
    interes_intercambio: Optional[str] = Field(None, examples=["Acepto libro de Estructuras de Datos"])

class PublicacionCreate(PublicacionBase):
    fotos_urls: Optional[List[str]] = Field(default=[], description="URLs de fotos subidas en Firebase Storage")

    @model_validator(mode="before")
    @classmethod
    def normalize_fields(cls, data: Any) -> Any:
        if isinstance(data, dict):
            # Normalización de alias para compatibilidad total
            if "fotos" in data and "fotos_urls" not in data:
                data["fotos_urls"] = data["fotos"]
            if "sede" in data and "sede_id" not in data:
                data["sede_id"] = data["sede"]
            if "facultad" in data and "facultad_id" not in data:
                data["facultad_id"] = data["facultad"]
            # Normalizar modalidad
            if "modalidad" in data and isinstance(data["modalidad"], str):
                mod = data["modalidad"].strip().upper().replace(" ", "_")
                if mod in ("VENTA", "SOLO_VENTA"):
                    data["modalidad"] = "VENTA"
                elif mod in ("INTERCAMBIO", "TRUEQUE", "SOLO_TRUEQUE"):
                    data["modalidad"] = "INTERCAMBIO"
                elif mod in ("DONACION", "DONACIÓN", "GRATIS"):
                    data["modalidad"] = "DONACION"
                else:
                    data["modalidad"] = "VENTA_O_INTERCAMBIO"
        return data

class PublicacionUpdate(BaseModel):
    titulo: Optional[str] = None
    autor: Optional[str] = None
    editorial: Optional[str] = None
    edicion: Optional[str] = None
    ano_publicacion: Optional[int] = None
    isbn: Optional[str] = None
    materia: Optional[str] = None
    semestre_sugerido: Optional[int] = None
    facultad_id: Optional[str] = None
    sede_id: Optional[str] = None
    condicion_libro: Optional[str] = None
    modalidad: Optional[str] = None
    precio: Optional[Decimal] = None
    descripcion: Optional[str] = None
    interes_intercambio: Optional[str] = None
    estado: Optional[str] = None

class PublicacionOut(PublicacionBase):
    id: str
    usuario_id: str
    estado: str
    vistas: int
    created_at: datetime
    updated_at: datetime
    fotos: List[FotoPublicacionOut] = []
    usuario: Optional[UsuarioOut] = None
    sede: Optional[SedeOut] = None
    facultad: Optional[FacultadOut] = None
    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# SCHEMAS DE PROPUESTAS DE INTERCAMBIO (MATCH/TRUEQUE)
# ==============================================================================

class SolicitudIntercambioCreate(BaseModel):
    publicacion_solicitada_id: str
    publicacion_ofrecida_id: Optional[str] = None
    mensaje_propuesta: str = Field(..., min_length=5, examples=["Te ofrezco mi libro de Álgebra Lineal a cambio."])

class SolicitudIntercambioRespuesta(BaseModel):
    aceptar: bool = True
    motivo_rechazo: Optional[str] = None

class SolicitudIntercambioOut(BaseModel):
    id: str
    publicacion_solicitada_id: str
    publicacion_ofrecida_id: Optional[str] = None
    usuario_solicitante_id: str
    usuario_receptor_id: str
    mensaje_propuesta: str
    estado: str
    fecha_respuesta: Optional[datetime] = None
    motivo_rechazo: Optional[str] = None
    created_at: datetime
    publicacion_solicitada: Optional[PublicacionOut] = None
    publicacion_ofrecida: Optional[PublicacionOut] = None
    usuario_solicitante: Optional[UsuarioOut] = None
    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# SCHEMAS DE RESERVAS Y TRANSACCIONES
# ==============================================================================

class TransaccionCreate(BaseModel):
    publicacion_id: str
    solicitud_intercambio_id: Optional[str] = None
    tipo_transaccion: str = Field(default="VENTA", examples=["VENTA", "INTERCAMBIO", "DONACION"])
    monto_pago: Decimal = Field(default=Decimal("0.00"), ge=0)
    punto_encuentro_id: str
    fecha_hora_encuentro: datetime

class TransaccionConfirmacionEntrega(BaseModel):
    codigo_verificacion: str = Field(..., min_length=4, max_length=6, examples=["482910"])
    observaciones: Optional[str] = None

class TransaccionOut(BaseModel):
    id: str
    publicacion_id: str
    solicitud_intercambio_id: Optional[str] = None
    vendedor_id: str
    comprador_id: str
    tipo_transaccion: str
    monto_pago: Decimal
    punto_encuentro_id: str
    fecha_hora_encuentro: datetime
    codigo_verificacion_entrega: str
    estado: str
    confirmado_vendedor: bool
    confirmado_comprador: bool
    observaciones_entrega: Optional[str] = None
    fecha_completada: Optional[datetime] = None
    created_at: datetime
    punto_encuentro: Optional[PuntoEncuentroOut] = None
    publicacion: Optional[PublicacionOut] = None
    vendedor: Optional[UsuarioOut] = None
    comprador: Optional[UsuarioOut] = None
    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# SCHEMAS DE CALIFICACIONES Y RESEÑAS
# ==============================================================================

class CalificacionCreate(BaseModel):
    transaccion_id: str
    puntuacion: int = Field(..., ge=1, le=5, examples=[5])
    comentario: Optional[str] = Field(None, examples=["Entrega rápida y libro en perfecto estado."])
    puntualidad: Optional[int] = Field(5, ge=1, le=5)
    estado_libro_fiel: Optional[int] = Field(5, ge=1, le=5)

class CalificacionOut(BaseModel):
    id: str
    transaccion_id: str
    evaluador_id: str
    evaluado_id: str
    puntuacion: int
    comentario: Optional[str] = None
    puntualidad: Optional[int] = None
    estado_libro_fiel: Optional[int] = None
    created_at: datetime
    evaluador: Optional[UsuarioOut] = None
    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# SCHEMAS DE MENSAJERÍA Y CHAT
# ==============================================================================

class MensajeCreate(BaseModel):
    contenido: Optional[str] = Field(None, examples=["Hola, ¿sigue disponible el libro?"])
    tipo: str = Field(default="TEXT", examples=["TEXT", "IMAGE"])
    foto_url: Optional[str] = Field(None, examples=["https://firebasestorage.googleapis.com/.../foto.jpg"])

class MensajeOut(BaseModel):
    id: str
    conversacion_id: str
    remitente_id: str
    contenido: str
    tipo: str = "TEXT"
    foto_url: Optional[str] = None
    leido: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class ConversacionOut(BaseModel):
    id: str
    publicacion_id: Optional[str] = None
    publicacion_titulo: Optional[str] = None
    publicacion_portada_url: Optional[str] = None
    publicacion_precio: Optional[float] = None
    publicacion_modalidad: Optional[str] = None
    usuario_uno_id: str
    usuario_dos_id: str
    otro_usuario_id: Optional[str] = None
    otro_usuario_nombre: Optional[str] = None
    otro_usuario_avatar_url: Optional[str] = None
    otro_usuario_email: Optional[str] = None
    otro_usuario_sede: Optional[str] = None
    mensajes_no_leidos: int = 0
    ultimo_mensaje_texto: Optional[str] = None
    ultimo_mensaje_tipo: Optional[str] = "TEXT"
    ultimo_mensaje_at: datetime
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# SCHEMAS DE NOTIFICACIONES
# ==============================================================================

class NotificacionOut(BaseModel):
    id: str
    usuario_id: str
    tipo: str
    titulo: str
    mensaje: str
    referencia_id: Optional[str] = None
    tipo_referencia: Optional[str] = None
    leida: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)
