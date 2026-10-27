import uuid
from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.api.deps import get_db, get_current_user, require_admin
from app.core.security import (
    hash_password, verify_password, verify_institutional_email,
    firebase_initialized
)
from app.models.entities import Usuario, Publicacion, SolicitudIntercambio, Transaccion, Calificacion
from app.schemas.schemas import (
    UsuarioOut, UsuarioUpdate, UsuarioRegister, UsuarioLogin, AuthTokenOut
)
from app.services.user_service import UserService
from app.services.publication_service import PublicationService


router = APIRouter(prefix="/auth", tags=["1. Autenticación y Control de Roles (RBAC)"])

@router.post("/register", response_model=AuthTokenOut, status_code=status.HTTP_201_CREATED, summary="Registro de usuario institucional")
def register_user(payload: UsuarioRegister, db: Session = Depends(get_db)):
    """
    Registra un nuevo estudiante en Unibooks verificando el dominio institucional (@ucundinamarca.edu.co).
    """
    clean_email = payload.email.lower().strip()

    # 1. Validación de dominio institucional
    if not verify_institutional_email(clean_email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debes utilizar tu correo institucional de la Universidad de Cundinamarca (@ucundinamarca.edu.co)"
        )

    # 2. Verificar si el correo ya se encuentra registrado
    existing_user = db.query(Usuario).filter(Usuario.email == clean_email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Este correo electrónico ya se encuentra registrado en Unibooks."
        )

    # 4. Creación o sincronización en Firebase Auth si está activo
    firebase_uid = f"fb_uid_{uuid.uuid4().hex[:12]}"
    if firebase_initialized:
        try:
            from firebase_admin import auth as fb_auth
            fb_user = fb_auth.create_user(
                email=clean_email,
                password=payload.password,
                display_name=payload.nombre_completo
            )
            firebase_uid = fb_user.uid
        except Exception:
            pass  # Fallback a UID local controlado

    # 5. Persistencia en Base de Datos Relacional
    hashed_pwd = hash_password(payload.password)
    user_role = (
        "ADMINISTRADOR"
        if clean_email in {"vargasdeiby54@gmail.com", "deibyvargas@ucundinamarca.edu.co"}
        else "ESTUDIANTE"
    )
    new_user = Usuario(
        id=str(uuid.uuid4()),
        firebase_uid=firebase_uid,
        email=clean_email,
        password_hash=hashed_pwd,
        nombre_completo=payload.nombre_completo,
        telefono=payload.telefono,
        sede_principal_id=payload.sede_principal_id,
        programa_id=payload.programa_id,
        rol=user_role,
        estado="ACTIVO",
        activo=True,
        reputacion_promedio=0.00,
        total_calificaciones=0
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    token = f"dev-{clean_email}"

    return AuthTokenOut(
        token=token,
        token_type="bearer",
        user=UsuarioOut.model_validate(new_user)
    )


@router.post("/login", response_model=AuthTokenOut, summary="Inicio de sesión directo")
def login_user(payload: UsuarioLogin, db: Session = Depends(get_db)):
    """
    Inicio de sesión para usuarios con correo institucional.
    """
    clean_email = payload.email.lower().strip()

    # Validación de dominio
    if not verify_institutional_email(clean_email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debes utilizar tu correo institucional de la Universidad de Cundinamarca (@ucundinamarca.edu.co)"
        )

    user = db.query(Usuario).filter(Usuario.email == clean_email).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo institucional o contraseña incorrectos."
        )

    # Verificación de contraseña
    pwd_valid = False
    if user.password_hash:
        pwd_valid = verify_password(payload.password, user.password_hash)

    if not pwd_valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo institucional o contraseña incorrectos."
        )

    if user.estado != "ACTIVO" or not user.activo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu cuenta ha sido suspendida por un administrador"
        )

    token = f"dev-{clean_email}"

    return AuthTokenOut(
        token=token,
        token_type="bearer",
        user=UsuarioOut.model_validate(user)
    )


@router.get("/me", response_model=UsuarioOut, summary="Obtener perfil del usuario autenticado")
def get_my_profile(current_user: Usuario = Depends(get_current_user)):
    """Retorna los datos del estudiante o docente autenticado en la Universidad de Cundinamarca."""
    return current_user


@router.put("/me", response_model=UsuarioOut, summary="Actualizar perfil del usuario")
def update_my_profile(
    profile_data: UsuarioUpdate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Permite actualizar teléfono, sede principal, programa académico, avatar y biografía."""
    return UserService.update_profile(db, current_user, profile_data)


@router.get("/users/{user_id}", response_model=UsuarioOut, summary="Consultar perfil público de un usuario")
def get_public_user_profile(user_id: str, db: Session = Depends(get_db)):
    """Obtiene información pública, sede y reputación con estrellas de un estudiante."""
    return UserService.get_by_id(db, user_id)


# ==============================================================================
# ENDPOINTS PROTEGIDOS POR CONTROL DE ACCESO BASADO EN ROLES (RBAC: ADMINISTRADOR)
# ==============================================================================

@router.get("/admin/stats", summary="Métricas de control global para Administrador")
def get_admin_dashboard_stats(
    admin: Usuario = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Retorna estadísticas clave del ecosistema Unibooks exclusivo para el rol ADMINISTRADOR."""
    total_usuarios = db.query(Usuario).count()
    total_estudiantes = db.query(Usuario).filter(Usuario.rol == "ESTUDIANTE").count()
    total_libros = db.query(Publicacion).count()
    libros_disponibles = db.query(Publicacion).filter(Publicacion.estado == "DISPONIBLE").count()
    total_intercambios = db.query(SolicitudIntercambio).count()
    total_transacciones = db.query(Transaccion).count()
    total_calificaciones = db.query(Calificacion).count()
    promedio_global = db.query(func.avg(Calificacion.puntuacion)).scalar()

    return {
        "admin": admin.nombre_completo,
        "rol": admin.rol,
        "metricas": {
            "total_usuarios": total_usuarios,
            "total_estudiantes": total_estudiantes,
            "total_publicaciones": total_libros,
            "publicaciones_activas": libros_disponibles,
            "solicitudes_intercambio": total_intercambios,
            "transacciones_totales": total_transacciones,
            "total_calificaciones": total_calificaciones,
            "promedio_global_satisfaccion": round(float(promedio_global), 1)
            if promedio_global is not None else 0.0,
        }
    }


@router.get("/admin/users", summary="Lista completa de usuarios para moderación RBAC")
def get_all_users_for_moderation(
    admin: Usuario = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Permite al Administrador auditar todas las cuentas del campus."""
    usuarios = db.query(Usuario).order_by(Usuario.created_at.desc()).all()
    return [UsuarioOut.model_validate(u) for u in usuarios]


@router.put("/admin/users/{user_id}/toggle-status", summary="Suspender o reactivar cuenta estudiantil")
def toggle_user_account_status(
    user_id: str,
    admin: Usuario = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Permite al Administrador suspender a un usuario por infracciones o reactivarlo."""
    user = db.query(Usuario).filter(Usuario.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

    user.activo = not user.activo
    user.estado = "ACTIVO" if user.activo else "SUSPENDIDO"
    db.commit()
    db.refresh(user)

    return {
        "id": user.id,
        "email": user.email,
        "nombre": user.nombre_completo,
        "activo": user.activo,
        "estado": user.estado,
        "status": "active" if user.activo else "suspended",
        "is_suspended": not user.activo,
        "mensaje": f"Estado del usuario actualizado a {user.estado} por el Administrador"
    }


@router.delete("/admin/publicaciones/{publication_id}", summary="Eliminación de publicación por moderación de contenidos")
def moderate_delete_publication(
    publication_id: str,
    admin: Usuario = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Permite eliminar únicamente publicaciones que sigan disponibles."""
    pub = db.query(Publicacion).filter(Publicacion.id == publication_id).first()
    if not pub:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Publicación no encontrada")
    title = pub.titulo
    PublicationService.delete(db, publication_id, admin)
    return {"mensaje": f"Publicación '{title}' eliminada exitosamente por moderación administrativa."}
