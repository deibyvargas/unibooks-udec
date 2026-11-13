"""
Control de concurrencia para Unibooks.

Anomalías que se previenen cuando varios estudiantes operan al mismo tiempo:

  * Lectura sucia (dirty read): leer datos de otra transacción aún no
    confirmada. -> Se evita con aislamiento READ COMMITTED (ver database.py).
  * Actualización perdida (lost update): dos peticiones leen `vistas = 10`,
    ambas escriben 11. -> `atomic_increment` hace `SET vistas = vistas + 1`
    dentro del motor, en una sola sentencia.
  * Doble reserva / doble respuesta (write skew / race condition): dos
    compradores reservan o el dueño acepta dos veces la misma solicitud.
    -> Bloqueo pesimista `SELECT ... FOR UPDATE` (`lock_row`) + transición
       de estado condicional "compare-and-set" (`compare_and_set`).
  * Violaciones de unicidad bajo carrera (dos INSERT simultáneos que pasan la
    validación previa). -> `commit_or_conflict` traduce IntegrityError a 409.

En PostgreSQL `FOR UPDATE` bloquea la fila hasta COMMIT/ROLLBACK. En SQLite
(desarrollo) SQLAlchemy omite la cláusula y la serialización la garantiza el
bloqueo de escritura de la base completa, por lo que el código es portable.
"""
from typing import Any, Dict, Optional, Type

from fastapi import HTTPException, status
from sqlalchemy import update
from sqlalchemy.exc import IntegrityError, OperationalError
from sqlalchemy.orm import Session, Query


def lock_row(query: Query, nowait: bool = False) -> Optional[Any]:
    """
    Bloqueo pesimista: SELECT ... FOR UPDATE.
    La fila queda reservada para esta transacción; otra transacción que intente
    bloquearla espera hasta que esta termine (o falla de inmediato con nowait).
    """
    try:
        return query.with_for_update(nowait=nowait).first()
    except OperationalError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El recurso está siendo modificado por otro usuario. Intenta de nuevo.",
        )


def compare_and_set(
    db: Session,
    model: Type[Any],
    row_id: str,
    expected: Dict[str, Any],
    values: Dict[str, Any],
) -> bool:
    """
    Control optimista: UPDATE ... WHERE id = :id AND <estado esperado>.
    Solo una de varias peticiones concurrentes logra el cambio (rowcount = 1);
    las demás detectan que el estado ya cambió (rowcount = 0).
    """
    stmt = update(model).where(model.id == row_id)
    for column, value in expected.items():
        stmt = stmt.where(getattr(model, column) == value)
    stmt = stmt.values(**values).execution_options(synchronize_session=False)
    result = db.execute(stmt)
    return result.rowcount == 1


def atomic_increment(db: Session, model: Type[Any], row_id: str, column: str, amount: int = 1) -> None:
    """Incremento atómico en el motor (evita la anomalía de actualización perdida)."""
    col = getattr(model, column)
    db.execute(
        update(model)
        .where(model.id == row_id)
        .values({column: col + amount})
        .execution_options(synchronize_session=False)
    )


def commit_or_conflict(db: Session, detail: str = "Conflicto de concurrencia: el registro ya existe o fue modificado.") -> None:
    """COMMIT; si la base rechaza la operación por unicidad/bloqueo, ROLLBACK y HTTP 409."""
    try:
        db.commit()
    except (IntegrityError, OperationalError):
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)


def raise_conflict(db: Session, detail: str) -> None:
    db.rollback()
    raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
