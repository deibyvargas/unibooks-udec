import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import Base, engine, SessionLocal
from app.db.init_db import init_database, seed_initial_data

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

def test_root_endpoint(client):
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["sistema"] == "Unibooks API"
    assert "Universidad de Cundinamarca" in data["universidad"]

def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_list_sedes(client):
    response = client.get("/api/v1/institucional/sedes")
    assert response.status_code == 200
    sedes = response.json()
    assert len(sedes) >= 8
    nombres = [s["nombre"] for s in sedes]
    assert any("Fusagasugá" in n for n in nombres)
    assert any("Girardot" in n for n in nombres)

def test_list_facultades(client):
    response = client.get("/api/v1/institucional/facultades")
    assert response.status_code == 200
    facultades = response.json()
    assert len(facultades) >= 4
    assert any("Ingeniería" in f["nombre"] for f in facultades)

def test_list_publicaciones_catalogo(client):
    response = client.get("/api/v1/publicaciones")
    assert response.status_code == 200
    pubs = response.json()
    assert len(pubs) >= 1
    # Verificar filtros por término de búsqueda
    response_search = client.get("/api/v1/publicaciones?q=Stewart")
    assert response_search.status_code == 200
    filtered = response_search.json()
    assert len(filtered) >= 1
    assert "Cálculo" in filtered[0]["titulo"]

def test_user_profile_me_dev_auth(client):
    # Probar autenticación con token de desarrollo
    headers = {"Authorization": "Bearer dev-carlos"}
    response = client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 200
    user = response.json()
    assert "carlos.mendoza@ucundinamarca.edu.co" in user["email"]
    assert user["reputacion_promedio"] is not None

def test_create_and_fetch_publication(client):
    headers = {"Authorization": "Bearer dev-carlos"}
    new_book = {
        "titulo": "Álgebra Lineal y sus Aplicaciones",
        "autor": "David C. Lay",
        "editorial": "Pearson",
        "edicion": "4ta Edición",
        "ano_publicacion": 2012,
        "isbn": "9786073213981",
        "materia": "Álgebra Lineal",
        "semestre_sugerido": 2,
        "sede_id": "11111111-1111-1111-1111-111111111101",
        "condicion_libro": "BUEN_ESTADO",
        "modalidad": "VENTA",
        "precio": 45000.0,
        "descripcion": "Libro de álgebra lineal con teoría de matrices y vectores en buen estado.",
        "fotos_urls": ["https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c"]
    }
    response = client.post("/api/v1/publicaciones", json=new_book, headers=headers)
    assert response.status_code == 201
    created = response.json()
    pub_id = created["id"]
    assert created["titulo"] == "Álgebra Lineal y sus Aplicaciones"
    assert len(created["fotos"]) == 1

    # Consultar detalle
    detail_res = client.get(f"/api/v1/publicaciones/{pub_id}")
    assert detail_res.status_code == 200
    assert detail_res.json()["vistas"] >= 1

def test_solicitud_intercambio_flow(client):
    # Carlos publica un libro, María solicita un intercambio
    headers_maria = {"Authorization": "Bearer dev-maria"}
    body_intercambio = {
        "publicacion_solicitada_id": "66666666-6666-6666-6666-666666666601",
        "mensaje_propuesta": "Hola Carlos, te ofrezco cambiar tu libro de Cálculo por uno de Macroeconomía."
    }
    response = client.post("/api/v1/intercambios", json=body_intercambio, headers=headers_maria)
    assert response.status_code == 201
    solicitud = response.json()
    solicitud_id = solicitud["id"]
    assert solicitud["estado"] == "PENDIENTE"

    # Carlos responde aceptando
    headers_carlos = {"Authorization": "Bearer dev-carlos"}
    resp_res = client.post(
        f"/api/v1/intercambios/{solicitud_id}/responder",
        json={"aceptar": True},
        headers=headers_carlos
    )
    assert resp_res.status_code == 200
    assert resp_res.json()["estado"] == "ACEPTADA"

def test_reserva_y_entrega_con_pin(client):
    # María reserva el libro de Base de Datos publicado por Carlos
    headers_maria = {"Authorization": "Bearer dev-maria"}
    reserva_body = {
        "publicacion_id": "66666666-6666-6666-6666-666666666602",
        "tipo_transaccion": "VENTA",
        "monto_pago": 80000.0,
        "punto_encuentro_id": "44444444-4444-4444-4444-444444444401",
        "fecha_hora_encuentro": "2026-10-20T14:30:00"
    }
    res = client.post("/api/v1/transacciones/reservar", json=reserva_body, headers=headers_maria)
    assert res.status_code == 201
    tx = res.json()
    tx_id = tx["id"]
    pin = tx["codigo_verificacion_entrega"]
    assert len(pin) == 6

    # Confirmar entrega en el punto seguro de la biblioteca
    confirm_res = client.post(
        f"/api/v1/transacciones/{tx_id}/confirmar-entrega",
        json={"codigo_verificacion": pin, "observaciones": "Entrega puntual en biblioteca"},
        headers=headers_maria
    )
    assert confirm_res.status_code == 200
    assert confirm_res.json()["estado"] == "COMPLETADA"

    # Carlos califica a María
    headers_carlos = {"Authorization": "Bearer dev-carlos"}
    rating_body = {
        "transaccion_id": tx_id,
        "puntuacion": 5,
        "comentario": "Excelente compradora, muy puntual y amable.",
        "puntualidad": 5,
        "estado_libro_fiel": 5
    }
    calif_res = client.post("/api/v1/calificaciones", json=rating_body, headers=headers_carlos)
    assert calif_res.status_code == 201
    assert calif_res.json()["puntuacion"] == 5


def test_chat_flow_with_multimedia(client):
    """Verifica el flujo completo de mensajería estilo WhatsApp: inicio, texto, fotos y lectura."""
    headers_maria = {"Authorization": "Bearer dev-maria"}
    headers_carlos = {"Authorization": "Bearer dev-carlos"}

    # Obtener perfil de Carlos y María
    me_carlos = client.get("/api/v1/auth/me", headers=headers_carlos).json()
    carlos_id = me_carlos["id"]

    res_books = client.get("/api/v1/publicaciones")
    assert res_books.status_code == 200
    libros = res_books.json()
    # Buscar un libro cuyo dueño sea Carlos
    libro_carlos = next((b for b in libros if b["usuario_id"] == carlos_id), libros[0])

    # María inicia conversación con Carlos sobre el libro
    init_res = client.post(
        f"/api/v1/chats/iniciar?destinatario_id={carlos_id}&publicacion_id={libro_carlos['id']}",
        headers=headers_maria
    )
    assert init_res.status_code == 200
    chat = init_res.json()
    chat_id = chat["id"]
    assert chat["publicacion_titulo"] == libro_carlos["titulo"]
    assert chat["otro_usuario_nombre"] is not None

    # María envía un mensaje de texto
    msg1_res = client.post(
        f"/api/v1/chats/conversaciones/{chat_id}/mensajes",
        json={"contenido": "¿Hola, sigue disponible para entrega hoy en Fusagasugá?", "tipo": "TEXT"},
        headers=headers_maria
    )
    assert msg1_res.status_code == 201
    assert msg1_res.json()["contenido"] == "¿Hola, sigue disponible para entrega hoy en Fusagasugá?"
    assert msg1_res.json()["tipo"] == "TEXT"

    # Carlos responde con una imagen/fotografía del estado de las páginas
    msg2_res = client.post(
        f"/api/v1/chats/conversaciones/{chat_id}/mensajes",
        json={
            "contenido": "Hola María, sí claro. Te adjunto foto de las páginas interiores:",
            "tipo": "IMAGE",
            "foto_url": "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600"
        },
        headers=headers_carlos
    )
    assert msg2_res.status_code == 201
    msg2 = msg2_res.json()
    assert msg2["tipo"] == "IMAGE"
    assert msg2["foto_url"] is not None

    # María consulta el historial de mensajes (debe marcar los mensajes recibidos como leídos)
    historial_res = client.get(
        f"/api/v1/chats/conversaciones/{chat_id}/mensajes",
        headers=headers_maria
    )
    assert historial_res.status_code == 200
    mensajes = historial_res.json()
    assert len(mensajes) >= 2


def test_chat_media_upload_endpoint(client):
    """Verifica la subida de un archivo fotográfico al backend."""
    import io
    headers_carlos = {"Authorization": "Bearer dev-carlos"}
    fake_image_bytes = b"\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xFF\xDB\x00C\x00"

    files = {
        "file": ("test_libro.jpg", io.BytesIO(fake_image_bytes), "image/jpeg")
    }
    upload_res = client.post("/api/v1/chats/upload-media", files=files, headers=headers_carlos)
    assert upload_res.status_code == 200
    data = upload_res.json()
    assert "url" in data
    assert data["filename"].endswith(".jpg")

