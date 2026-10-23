# FASE 3: MOTOR DE CHAT ESTILO WHATSAPP Y GESTIÓN DE MULTIMEDIA
## Proyecto de Grado: "Unibooks: Plataforma para compra, venta e intercambio de libros para la Universidad de Cundinamarca"

---

## 1. Visión y Alcance de la Fase 3

La **Fase 3** consolida el componente de comunicación directa y multimedia del ecosistema Unibooks. Diseñado bajo una **arquitectura híbrida**, permite a los estudiantes de la Universidad de Cundinamarca entablar conversaciones seguras vinculadas directamente al libro que desean adquirir, intercambiar o recibir en donación.

```
+---------------------------------------------------------------------------------------+
|                       ARQUITECTURA DE MENSAJERÍA Y MULTIMEDIA                         |
+---------------------------------------------------------------------------------------+
                                          |
                +-------------------------+-------------------------+
                |                                                   |
                v                                                   v
+-------------------------------+                   +-------------------------------+
|     CLIENTE FLUTTER           |                   |    PERSISTENCIA Y STORAGE     |
| - ChatListScreen (Inbox)      |                   | 1. Cloud Firestore (NoSQL):   |
|   * Bandeja estilo WhatsApp   |                   |    - Colección /chats         |
|   * Badges de no leídos       |                   |    - Subcolección /messages   |
|   * Chip de libro vinculado   | <--- HTTPS / ---> | 2. Cloud Storage:             |
| - ChatDetailScreen:           |      REST API     |    - /avatars/{userId}/       |
|   * Cabecera con datos libro  |                   |    - /publications/{bookId}/  |
|   * Burbujas verde/blanco     |                   |    - /chats/{chatId}/         |
|   * Doble check de lectura    |                   | 3. FastAPI + PostgreSQL:      |
|   * Selector de fotos libro   |                   |    - Auditoría relacional     |
|   * Visor con Zoom / Pan      |                   |    - Endpoints /chats         |
+-------------------------------+                   +-------------------------------+
```

---

## 2. Modelo de Datos y Esquemas Implementados

### 2.1. Entidades en Base de Datos Relacional (PostgreSQL / SQLite)
* **Tabla `conversaciones`:**
  - `id`: UUID (Clave Primaria).
  - `publicacion_id`: UUID (Referencia al libro negociado, `ON DELETE SET NULL`).
  - `usuario_uno_id` / `usuario_dos_id`: UUIDs de los estudiantes involucrados.
  - `ultimo_mensaje_texto`: Snippet del último mensaje enviado.
  - `ultimo_mensaje_at`: Timestamp de la última interacción para ordenar el Inbox.
* **Tabla `mensajes`:**
  - `id`: UUID (Clave Primaria).
  - `conversacion_id`: UUID (Clave foránea con borrado en cascada).
  - `remitente_id`: UUID del estudiante emisor.
  - `contenido`: Texto del mensaje o pie de foto.
  - `tipo`: ENUM/VARCHAR (`TEXT` o `IMAGE`).
  - `foto_url`: URL de la fotografía alojada en Firebase Storage o servidor estático.
  - `leido`: Booleano para confirmación de entrega y lectura (doble check).
  - `created_at`: Timestamp de emisión.

### 2.2. Modelo NoSQL en Cloud Firestore (`database/firestore.rules`)
```json
// Documento: /chats/{chatId}
{
  "chatId": "lib_01_carlos_maria",
  "publicacionId": "66666666-6666-6666-6666-666666666601",
  "tituloLibro": "Cálculo: Trascendentes Tempranas",
  "portadaLibroUrl": "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c",
  "precioLibro": 65000.0,
  "participantes": ["carlos_id", "maria_id"],
  "ultimoMensajeTexto": "Te comparto foto de la portada original del libro.",
  "ultimoMensajeTipo": "IMAGE",
  "ultimoMensajeTimestamp": "2026-10-15T12:05:00Z"
}

// Subcolección: /chats/{chatId}/messages/{messageId}
{
  "messageId": "msg_001",
  "remitenteId": "carlos_id",
  "contenido": "Te comparto foto de la portada original del libro.",
  "tipo": "IMAGE",
  "fotoUrl": "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c",
  "leido": true,
  "timestamp": "2026-10-15T12:05:00Z"
}
```

---

## 3. Componentes Desarrollados en el Cliente Flutter

| Componente | Archivo | Descripción Funcional |
| :--- | :--- | :--- |
| **Modelos de Chat** | [`chat_model.dart`](file:///d:/Deiby%20Vargas/Documents/PROYECTO%202026/frontend/lib/models/chat_model.dart) | Clases `ConversacionModel` y `MensajeModel` con soporte para tipos de mensaje, fotos y métodos auxiliares `esMio` y `esImagen`. |
| **Proveedor de Estado** | [`chat_provider.dart`](file:///d:/Deiby%20Vargas/Documents/PROYECTO%202026/frontend/lib/providers/chat_provider.dart) | Gestión reactiva de mensajes, envío en background, contador acumulado de mensajes no leídos y sondeo en tiempo real cada 3.5 segundos. |
| **Bandeja de Entrada** | [`chat_list_screen.dart`](file:///d:/Deiby%20Vargas/Documents/PROYECTO%202026/frontend/lib/screens/chat/chat_list_screen.dart) | Lista de hilos conversacionales estilo WhatsApp con avatares, etiquetas del libro de interés, buscador rápido y badge de no leídos. |
| **Detalle de Chat** | [`chat_detail_screen.dart`](file:///d:/Deiby%20Vargas/Documents/PROYECTO%202026/frontend/lib/screens/chat/chat_detail_screen.dart) | Conversación activa: cabecera con avatar e información de sede, banner fijo del libro, burbujas diferenciadas, doble check azul y visor interactivo de fotos. |
| **Navegación Principal** | [`main_navigation_screen.dart`](file:///d:/Deiby%20Vargas/Documents/PROYECTO%202026/frontend/lib/screens/main_navigation_screen.dart) | Integración de la pestaña "Mensajes" con indicador Badge dinámico tanto en versión Móvil como Web. |
| **Detalle de Libro** | [`book_detail_screen.dart`](file:///d:/Deiby%20Vargas/Documents/PROYECTO%202026/frontend/lib/screens/catalog/book_detail_screen.dart) | Botón "Contactar por Chat (WhatsApp UDEC)" que inicia o retoma la conversación instantáneamente con el estudiante vendedor. |

---

## 4. Reglas de Negocio y Seguridad Institucional

1. **Aislamiento de Chats:** Un estudiante solo puede acceder y enviar mensajes a conversaciones donde figure en la tupla `(usuario_uno_id, usuario_dos_id)`.
2. **Contextualización Obligatoria:** Cada conversación vincula el `publicacion_id`, evitando ambigüedades respecto a qué libro o edición se está negociando.
3. **Evidencia Fotográfica del Estado Físico:** El selector multimedia permite a los estudiantes enviar fotografías de la portada, páginas interiores y lomo del libro para verificar su estado antes de acordar el encuentro en el campus.
4. **Visor de Pantalla Completa:** Al tocar cualquier fotografía dentro del chat, se activa un diálogo inmersivo con gestos de zoom y desplazamiento para inspección detallada.
5. **Confirmación de Lectura:** Marcado automático de mensajes leídos cuando el destinatario abre el chat, reflejado en el emisor con el icono de doble check azul.

---

## 5. Pruebas Automatizadas del Backend (100% Aprobadas)

Se ejecutó la suite completa de pruebas unitarias e integración en FastAPI:
```bash
backend/.venv/Scripts/python.exe -m pytest backend/tests/ -v
```

**Resultados Obtenidos:**
* `test_root_endpoint`: PASSED
* `test_health_endpoint`: PASSED
* `test_list_sedes`: PASSED
* `test_list_facultades`: PASSED
* `test_list_publicaciones_catalogo`: PASSED
* `test_user_profile_me_dev_auth`: PASSED
* `test_create_and_fetch_publication`: PASSED
* `test_solicitud_intercambio_flow`: PASSED
* `test_reserva_y_entrega_con_pin`: PASSED
* `test_chat_flow_with_multimedia`: **PASSED** (Inicia chat, intercambia texto, envía foto y valida lectura).
* `test_chat_media_upload_endpoint`: **PASSED** (Subida de imagen y generación de URL estática/storage).

**Total: 11 tests aprobados (100% de éxito).**
