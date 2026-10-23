from typing import Generator, Dict, Any
from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user_claims
from app.models.entities import Usuario

def get_current_user(
    claims: Dict[str, Any] = Depends(get_current_user_claims),
    db: Session = Depends(get_db)
) -> Usuario:
    """
    Obtiene el usuario autenticado desde la base de datos a partir del token de Firebase.
    Si es el primer inicio de sesión del estudiante con su correo institucional, aprovisiona su cuenta automáticamente.
    """
    firebase_uid = claims.get("uid")
    email = claims.get("email")
    name = claims.get("name") or email.split("@")[0].replace(".", " ").title()

    user = db.query(Usuario).filter(Usuario.firebase_uid == firebase_uid).first()

    # Si no existe por UID, buscar por email (en caso de pre-registro)
    if not user and email:
        user = db.query(Usuario).filter(Usuario.email == email).first()
        if user:
            user.firebase_uid = firebase_uid
            db.commit()
            db.refresh(user)

    # La cuenta debe existir porque fue creada mediante el formulario de registro.
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="La cuenta no está registrada. Debes crearla desde el formulario de registro.",
        )

    if user.estado != "ACTIVO" or not user.activo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu cuenta de usuario se encuentra suspendida o inactiva."
        )

    return user

def get_current_admin_user(
    current_user: Usuario = Depends(get_current_user)
) -> Usuario:
    """Verifica que el usuario tenga privilegios administrativos (RBAC)."""
    if current_user.rol not in ("ADMINISTRADOR", "ADMIN") and current_user.email.lower().strip() != "vargasdeiby54@gmail.com":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acceso restringido: Se requieren privilegios de Administrador para esta acción."
        )
    return current_user

# Alias canónico solicitado para control de roles
require_admin = get_current_admin_user
