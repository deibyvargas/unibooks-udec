"""
Pruebas de transacciones y control de concurrencia.

Verifican que el flujo completo (publicar -> reservar -> aceptar -> entregar
-> calificar) sigue funcionando y que las operaciones repetidas o simultáneas
se rechazan sin corromper los datos.
"""
import threading

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import Base, engine, SessionLocal, transaction_scope, QueryStats
from app.db.init_db import init_database, seed_initial_data
from app.models.entities import Publicacion, Notificacion

SEDE = "11111111-1111-1111-1111-111111111101"
PUNTO = "44444444-4444-4444-4444-444444444401"


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


def _register(client, email, nombre):
    res = client.post("/api/v1/auth/register", json={
        "email": email, "password": "Password123!", "nombre_completo": nombre, "telefono": "3100000000",
    })
    assert res.status_code == 201, res.text
    data = res.json()
    return {"Authorization": f"Bearer {data['token']}"}, data["user"]["id"]


def _publish(client, headers, titulo="Bases de Datos Fundamentos"):
    res = client.post("/api/v1/publicaciones", headers=headers, json={
        "titulo": titulo, "autor": "Silberschatz", "sede_id": SEDE,
        "modalidad": "VENTA", "precio": 50000, "descripcion": "Libro de bases de datos en buen estado",
    })
    assert res.status_code == 201, res.text
    return res.json()["id"]


def _reserve(client, headers, pub_id):
    return client.post("/api/v1/transacciones/reservar", headers=headers, json={
        "publicacion_id": pub_id, "tipo_transaccion": "VENTA", "monto_pago": 50000,
        "punto_encuentro_id": PUNTO, "fecha_hora_encuentro": "2026-12-01T10:00:00",
    })


def test_flujo_completo_con_controles_de_concurrencia(client):
    h_vend, _ = _register(client, "vendedor.test@ucundinamarca.edu.co", "Vendedor Test")
    h_comp, _ = _register(client, "comprador.test@ucundinamarca.edu.co", "Comprador Test")
    pub_id = _publish(client, h_vend)

    # Reserva normal
    res = _reserve(client, h_comp, pub_id)
    assert res.status_code == 201, res.text
    tx_id = res.json()["id"]

    # Doble reserva del mismo estudiante -> 409
    assert _reserve(client, h_comp, pub_id).status_code == 409

    # El dueño acepta; una segunda respuesta debe ser rechazada
    res = client.post(f"/api/v1/transacciones/{tx_id}/responder", headers=h_vend, json={"aceptar": True})
    assert res.status_code == 200, res.text
    assert res.json()["estado"] == "PENDIENTE_ENCUENTRO"
    assert client.post(f"/api/v1/transacciones/{tx_id}/responder", headers=h_vend, json={"aceptar": True}).status_code == 409

    # El comprador ve el PIN y el vendedor lo ingresa
    pin = client.get(f"/api/v1/transacciones/{tx_id}", headers=h_comp).json()["codigo_verificacion_entrega"]
    assert len(pin) == 4
    res = client.post(f"/api/v1/transacciones/{tx_id}/confirmar-entrega", headers=h_vend, json={"codigo_verificacion": pin})
    assert res.status_code == 200, res.text
    assert res.json()["estado"] == "COMPLETADA"

    # Segunda confirmación no se aplica
    res2 = client.post(f"/api/v1/transacciones/{tx_id}/confirmar-entrega", headers=h_vend, json={"codigo_verificacion": pin})
    assert res2.status_code in (400, 409)

    with SessionLocal() as db:
        assert db.get(Publicacion, pub_id).estado == "NO_DISPONIBLE"

    # Calificación única por participante
    body = {"transaccion_id": tx_id, "puntuacion": 5}
    assert client.post("/api/v1/calificaciones", headers=h_comp, json=body).status_code == 201
    assert client.post("/api/v1/calificaciones", headers=h_comp, json=body).status_code in (400, 409)


def test_intercambio_no_se_responde_dos_veces(client):
    h_a, _ = _register(client, "dueno.libro@ucundinamarca.edu.co", "Dueno Libro")
    h_b, _ = _register(client, "interesado.libro@ucundinamarca.edu.co", "Interesado Libro")
    pub_id = _publish(client, h_a, "Estructuras de Datos")
    res = client.post("/api/v1/intercambios", headers=h_b, json={
        "publicacion_solicitada_id": pub_id, "mensaje_propuesta": "Te ofrezco mi libro de Álgebra",
    })
    assert res.status_code == 201, res.text
    sol_id = res.json()["id"]
    assert client.post(f"/api/v1/intercambios/{sol_id}/responder", headers=h_a, json={"aceptar": True}).status_code == 200
    assert client.post(f"/api/v1/intercambios/{sol_id}/responder", headers=h_a, json={"aceptar": False}).status_code in (400, 409)


def test_contador_de_vistas_atomico_sin_actualizaciones_perdidas(client):
    h, _ = _register(client, "vistas.test@ucundinamarca.edu.co", "Vistas Test")
    pub_id = _publish(client, h, "Sistemas Operativos")
    n_hilos, por_hilo = 5, 4

    def visitar():
        c = TestClient(app)
        for _ in range(por_hilo):
            assert c.get(f"/api/v1/publicaciones/{pub_id}").status_code == 200

    hilos = [threading.Thread(target=visitar) for _ in range(n_hilos)]
    for t in hilos:
        t.start()
    for t in hilos:
        t.join()

    with SessionLocal() as db:
        assert db.get(Publicacion, pub_id).vistas == n_hilos * por_hilo


def test_transaction_scope_hace_rollback_si_falla(client):
    _, user_id = _register(client, "rollback.test@ucundinamarca.edu.co", "Rollback Test")
    with SessionLocal() as db:
        antes = db.query(Notificacion).count()
        with pytest.raises(RuntimeError):
            with transaction_scope(db):
                db.add(Notificacion(usuario_id=user_id, tipo="X", titulo="t", mensaje="m"))
                db.flush()
                raise RuntimeError("fallo a mitad de la transacción")
        assert db.query(Notificacion).count() == antes


def test_estadisticas_de_consultas_registran_tiempos(client):
    client.get("/api/v1/institucional/sedes")
    stats = QueryStats.snapshot()
    assert stats["total_consultas"] > 0
    assert stats["tiempo_promedio_ms"] >= 0


def test_diagnostico_bd_solo_admin_y_usa_indices(client):
    h_est, _ = _register(client, "estudiante.diag@ucundinamarca.edu.co", "Estudiante Diag")
    assert client.get("/api/v1/admin/base-datos/rendimiento", headers=h_est).status_code == 403

    h_admin, _ = _register(client, "vargasdeiby54@gmail.com", "Admin Diag")
    res = client.get("/api/v1/admin/base-datos/rendimiento", headers=h_admin)
    assert res.status_code == 200, res.text
    nombres = {ix["nombre"] for ix in res.json()["indices"]["publicaciones"]}
    assert "idx_pub_estado_sede_fecha" in nombres

    plan = client.get("/api/v1/admin/base-datos/plan-catalogo", headers=h_admin)
    assert plan.status_code == 200, plan.text
    assert plan.json()["usa_indice"] is True
