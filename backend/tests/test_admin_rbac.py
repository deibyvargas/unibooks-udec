import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import Base, engine, SessionLocal
from app.db.init_db import init_database, seed_initial_data
from app.models.entities import Usuario, Publicacion, Transaccion, SolicitudIntercambio

@pytest.fixture(scope="function", autouse=True)
def setup_test_db():
    Base.metadata.drop_all(bind=engine)
    init_database()
    db = SessionLocal()
    seed_initial_data(db)
    db.close()
    yield

@pytest.fixture
def client():
    return TestClient(app)

def test_admin_suspend_user_and_block_login(client):
    # 1. Registrar estudiante
    reg_student = client.post("/api/v1/auth/register", json={
        "email": "juan.perez@ucundinamarca.edu.co",
        "password": "Password123!",
        "nombre_completo": "Juan Perez",
        "telefono": "3101234567"
    })
    assert reg_student.status_code == 201
    student_id = reg_student.json()["user"]["id"]

    # 2. Registrar Administrador Principal
    reg_admin = client.post("/api/v1/auth/register", json={
        "email": "vargasdeiby54@gmail.com",
        "password": "AdminPassword123!",
        "nombre_completo": "Deiby Vargas",
        "telefono": "3201234567"
    })
    assert reg_admin.status_code == 201
    admin_token = reg_admin.json()["token"]

    # 3. Estudiante puede iniciar sesión inicialmente
    login_ok = client.post("/api/v1/auth/login", json={
        "email": "juan.perez@ucundinamarca.edu.co",
        "password": "Password123!"
    })
    assert login_ok.status_code == 200

    # 4. Administrador suspende la cuenta del estudiante
    toggle_res = client.put(
        f"/api/v1/auth/admin/users/{student_id}/toggle-status",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert toggle_res.status_code == 200
    toggle_data = toggle_res.json()
    assert toggle_data["estado"] == "SUSPENDIDO"
    assert toggle_data["is_suspended"] is True
    assert toggle_data["activo"] is False

    # 5. Estudiante suspendido intenta iniciar sesión: Bloqueo estricto con mensaje requerido
    login_blocked = client.post("/api/v1/auth/login", json={
        "email": "juan.perez@ucundinamarca.edu.co",
        "password": "Password123!"
    })
    assert login_blocked.status_code == 403
    assert login_blocked.json()["detail"] == "Tu cuenta ha sido suspendida por un administrador"

    # 6. Administrador reactiva la cuenta
    reactivate_res = client.put(
        f"/api/v1/auth/admin/users/{student_id}/toggle-status",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert reactivate_res.status_code == 200
    assert reactivate_res.json()["estado"] == "ACTIVO"
    assert reactivate_res.json()["activo"] is True

    # 7. El estudiante reactivado puede volver a iniciar sesión
    login_after_reactivate = client.post("/api/v1/auth/login", json={
        "email": "juan.perez@ucundinamarca.edu.co",
        "password": "Password123!"
    })
    assert login_after_reactivate.status_code == 200

def test_admin_can_delete_any_book_and_clean_dependencies(client):
    # 1. Registrar Estudiante Autor
    reg_student = client.post("/api/v1/auth/register", json={
        "email": "autor.libro@ucundinamarca.edu.co",
        "password": "Password123!",
        "nombre_completo": "Autor Libro",
        "telefono": "3111234567"
    })
    assert reg_student.status_code == 201
    author_id = reg_student.json()["user"]["id"]

    # 2. Registrar Administrador
    reg_admin = client.post("/api/v1/auth/register", json={
        "email": "vargasdeiby54@gmail.com",
        "password": "AdminPassword123!",
        "nombre_completo": "Deiby Vargas Admin",
        "telefono": "3201234567"
    })
    assert reg_admin.status_code == 201
    admin_token = reg_admin.json()["token"]

    # 3. Crear una publicación de libro en la base de datos
    db = SessionLocal()
    new_book = Publicacion(
        id="book-1234-test",
        usuario_id=author_id,
        titulo="Cálculo Diferencial e Integral",
        autor="James Stewart",
        sede_id="11111111-1111-1111-1111-111111111101",
        condicion_libro="BUEN_ESTADO",
        modalidad="VENTA",
        precio=50000.0,
        descripcion="Libro de cálculo para ingeniería",
        estado="DISPONIBLE"
    )
    db.add(new_book)

    from datetime import datetime
    # Crear una transacción pendiente vinculada
    tx = Transaccion(
        id="tx-1234-test",
        publicacion_id="book-1234-test",
        vendedor_id=author_id,
        comprador_id=author_id,
        tipo_transaccion="VENTA",
        monto_pago=50000.0,
        punto_encuentro_id="44444444-4444-4444-4444-444444444401",
        fecha_hora_encuentro=datetime.now(),
        codigo_verificacion_entrega="1234",
        estado="PENDIENTE_ENCUENTRO"
    )
    db.add(tx)

    # Crear una solicitud de intercambio vinculada
    solicitud = SolicitudIntercambio(
        id="sol-1234-test",
        publicacion_solicitada_id="book-1234-test",
        usuario_solicitante_id=author_id,
        usuario_receptor_id=author_id,
        mensaje_propuesta="Propuesta de prueba",
        estado="PENDIENTE"
    )
    db.add(solicitud)
    db.commit()
    db.close()

    # 4. El Administrador elimina el libro (aunque NO sea el autor)
    delete_res = client.delete(
        "/api/v1/publicaciones/book-1234-test",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert delete_res.status_code == 204

    # 5. Verificar que el libro y sus solicitudes asociadas fueron eliminados
    db2 = SessionLocal()
    book_in_db = db2.query(Publicacion).filter(Publicacion.id == "book-1234-test").first()
    assert book_in_db is None

    tx_in_db = db2.query(Transaccion).filter(Transaccion.publicacion_id == "book-1234-test").first()
    assert tx_in_db is None

    sol_in_db = db2.query(SolicitudIntercambio).filter(
        SolicitudIntercambio.publicacion_solicitada_id == "book-1234-test"
    ).first()
    assert sol_in_db is None
    db2.close()

def test_admin_cannot_delete_completed_or_unavailable_book(client):
    # 1. Registrar Administrador
    reg_admin = client.post("/api/v1/auth/register", json={
        "email": "vargasdeiby54@gmail.com",
        "password": "AdminPassword123!",
        "nombre_completo": "Deiby Vargas Admin",
        "telefono": "3201234567"
    })
    assert reg_admin.status_code == 201
    admin_token = reg_admin.json()["token"]

    # 2. Registrar Autor
    reg_student = client.post("/api/v1/auth/register", json={
        "email": "estudiante.donador@ucundinamarca.edu.co",
        "password": "Password123!",
        "nombre_completo": "Donador Estudiante",
        "telefono": "3119998877"
    })
    assert reg_student.status_code == 201
    author_id = reg_student.json()["user"]["id"]

    # 3. Crear publicación donada/completada (estado NO_DISPONIBLE)
    db = SessionLocal()
    completed_book = Publicacion(
        id="book-donated-test",
        usuario_id=author_id,
        titulo="Libro Donado UDEC",
        autor="Autor Donador",
        sede_id="11111111-1111-1111-1111-111111111101",
        condicion_libro="BUEN_ESTADO",
        modalidad="DONACION",
        precio=0.0,
        descripcion="Libro entregado a otro estudiante por donación",
        estado="NO_DISPONIBLE"
    )
    db.add(completed_book)
    db.commit()
    db.close()

    # 4. El Administrador intenta eliminar el libro que ya fue entregado/donado
    delete_res = client.delete(
        "/api/v1/publicaciones/book-donated-test",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert delete_res.status_code == 409
    assert "No se puede eliminar un libro que ya fue donado, vendido, intercambiado o entregado." in delete_res.json()["detail"]

    # 5. Comprobar que el libro sigue existiendo en base de datos como historial
    db2 = SessionLocal()
    persisted_book = db2.query(Publicacion).filter(Publicacion.id == "book-donated-test").first()
    assert persisted_book is not None
    assert persisted_book.estado == "NO_DISPONIBLE"
    db2.close()

