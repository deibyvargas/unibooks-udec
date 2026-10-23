from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.entities import Usuario
from app.schemas.schemas import UsuarioUpdate

class UserService:
    @staticmethod
    def get_by_id(db: Session, user_id: str) -> Usuario:
        user = db.query(Usuario).filter(Usuario.id == user_id).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario institucional no encontrado"
            )
        return user

    @staticmethod
    def get_by_firebase_uid(db: Session, firebase_uid: str) -> Usuario:
        user = db.query(Usuario).filter(Usuario.firebase_uid == firebase_uid).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no registrado en la base de datos"
            )
        return user

    @staticmethod
    def update_profile(db: Session, user: Usuario, update_data: UsuarioUpdate) -> Usuario:
        update_dict = update_data.model_dump(exclude_unset=True)
        for field, value in update_dict.items():
            setattr(user, field, value)
        
        db.commit()
        db.refresh(user)
        return user
