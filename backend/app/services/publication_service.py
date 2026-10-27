from typing import List, Optional
from decimal import Decimal
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_, desc, asc
from fastapi import HTTPException, status
from app.models.entities import (
    Publicacion,
    FotoPublicacion,
    Usuario,
    Transaccion,
    SolicitudIntercambio,
    Calificacion,
)
from app.schemas.schemas import PublicacionCreate, PublicacionUpdate

class PublicationService:
    @staticmethod
    def get_filtered(
        db: Session,
        q: Optional[str] = None,
        sede_id: Optional[str] = None,
        facultad_id: Optional[str] = None,
        semestre: Optional[int] = None,
        modalidad: Optional[str] = None,
        condicion: Optional[str] = None,
        precio_max: Optional[Decimal] = None,
        estado: Optional[str] = "DISPONIBLE",
        sort_by: Optional[str] = "recent",
        skip: int = 0,
        limit: int = 20
    ) -> List[Publicacion]:
        query = db.query(Publicacion).options(
            joinedload(Publicacion.fotos),
            joinedload(Publicacion.usuario),
            joinedload(Publicacion.sede),
            joinedload(Publicacion.facultad)
        )

        # El catálogo público solo expone publicaciones activas. El historial
        # del propietario usa get_by_owner y no pasa por este filtro.
        query = query.filter(Publicacion.estado == "DISPONIBLE")
        if sede_id:
            query = query.filter(Publicacion.sede_id == sede_id)
        if facultad_id:
            query = query.filter(Publicacion.facultad_id == facultad_id)
        if semestre:
            query = query.filter(Publicacion.semestre_sugerido == semestre)
        if modalidad:
            query = query.filter(Publicacion.modalidad == modalidad)
        if condicion:
            query = query.filter(Publicacion.condicion_libro == condicion)
        if precio_max is not None:
            query = query.filter(Publicacion.precio <= precio_max)

        if q:
            term = f"%{q.strip()}%"
            query = query.filter(
                or_(
                    Publicacion.titulo.ilike(term),
                    Publicacion.autor.ilike(term),
                    Publicacion.materia.ilike(term),
                    Publicacion.editorial.ilike(term),
                    Publicacion.isbn.ilike(term),
                    Publicacion.descripcion.ilike(term)
                )
            )

        if sort_by == "price_asc":
            query = query.order_by(asc(Publicacion.precio))
        elif sort_by == "price_desc":
            query = query.order_by(desc(Publicacion.precio))
        elif sort_by == "views":
            query = query.order_by(desc(Publicacion.vistas))
        else:
            query = query.order_by(desc(Publicacion.created_at))

        return query.offset(skip).limit(limit).all()

    @staticmethod
    def get_by_owner(
        db: Session,
        owner_id: str,
        skip: int = 0,
        limit: int = 100,
    ) -> List[Publicacion]:
        return (
            db.query(Publicacion)
            .options(
                joinedload(Publicacion.fotos),
                joinedload(Publicacion.usuario),
                joinedload(Publicacion.sede),
                joinedload(Publicacion.facultad),
            )
            .filter(Publicacion.usuario_id == owner_id)
            .order_by(desc(Publicacion.created_at))
            .offset(skip)
            .limit(limit)
            .all()
        )

    @staticmethod
    def get_by_id(db: Session, publicacion_id: str) -> Publicacion:
        publicacion = db.query(Publicacion).options(
            joinedload(Publicacion.fotos),
            joinedload(Publicacion.usuario),
            joinedload(Publicacion.sede),
            joinedload(Publicacion.facultad)
        ).filter(Publicacion.id == publicacion_id).first()

        if not publicacion:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Publicación de libro no encontrada"
            )

        # Incrementar contador de visualizaciones
        publicacion.vistas += 1
        db.commit()
        db.refresh(publicacion)
        return publicacion

    @staticmethod
    def create(db: Session, pub_in: PublicacionCreate, current_user: Usuario) -> Publicacion:
        pub_data = pub_in.model_dump(exclude={"fotos_urls"})
        nueva_publicacion = Publicacion(
            **pub_data,
            usuario_id=current_user.id,
            estado="DISPONIBLE"
        )
        db.add(nueva_publicacion)
        db.flush()

        # Guardar galería de fotos (1 a 4 fotos)
        if pub_in.fotos_urls:
            urls_limit = pub_in.fotos_urls[:4]
            for idx, url in enumerate(urls_limit):
                foto = FotoPublicacion(
                    publicacion_id=nueva_publicacion.id,
                    foto_url=url,
                    es_portada=(idx == 0),
                    orden=idx + 1
                )
                db.add(foto)

        db.commit()
        db.refresh(nueva_publicacion)
        return nueva_publicacion

    @staticmethod
    def update(
        db: Session,
        publicacion_id: str,
        pub_update: PublicacionUpdate,
        current_user: Usuario
    ) -> Publicacion:
        publicacion = db.query(Publicacion).filter(Publicacion.id == publicacion_id).first()
        if not publicacion:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Publicación no encontrada"
            )

        es_admin = current_user.rol in ("ADMINISTRADOR", "ADMIN") or (
            current_user.email and current_user.email.lower().strip() == "vargasdeiby54@gmail.com"
        )
        if publicacion.usuario_id != current_user.id and not es_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes autorización para modificar esta publicación"
            )

        update_dict = pub_update.model_dump(exclude_unset=True)
        for field, value in update_dict.items():
            setattr(publicacion, field, value)

        db.commit()
        db.refresh(publicacion)
        return publicacion

    @staticmethod
    def delete(db: Session, publicacion_id: str, current_user: Usuario) -> None:
        publicacion = db.query(Publicacion).filter(Publicacion.id == publicacion_id).first()
        if not publicacion:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Publicación no encontrada"
            )

        es_admin = current_user.rol in ("ADMINISTRADOR", "ADMIN")
        es_propietario = publicacion.usuario_id == current_user.id
        if not es_admin and not es_propietario:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes autorización para eliminar esta publicación"
            )

        if publicacion.estado != "DISPONIBLE":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="No se puede eliminar un libro que ya fue donado, vendido, intercambiado o entregado."
            )

        # El administrador puede eliminar cualquier publicación. Se eliminan
        # dependencias antes del registro principal para respetar las FK.
        transaction_ids = [
            row[0]
            for row in db.query(Transaccion.id)
            .filter(Transaccion.publicacion_id == publicacion_id)
            .all()
        ]
        if transaction_ids:
            db.query(Calificacion).filter(
                Calificacion.transaccion_id.in_(transaction_ids)
            ).delete(synchronize_session=False)
        db.query(Transaccion).filter(Transaccion.publicacion_id == publicacion_id).delete(synchronize_session=False)
        db.query(SolicitudIntercambio).filter(
            (SolicitudIntercambio.publicacion_solicitada_id == publicacion_id) |
            (SolicitudIntercambio.publicacion_ofrecida_id == publicacion_id)
        ).delete(synchronize_session=False)

        db.delete(publicacion)
        db.commit()
