# MODELADO DE DATOS HÍBRIDO (POSTGRESQL + FIREBASE FIRESTORE)
## Proyecto de Grado: "Unibooks: Plataforma para compra, venta e intercambio de libros para la Universidad de Cundinamarca"

---

## 1. Visión de la Arquitectura de Datos Híbrida

Para responder con máxima eficiencia a los requisitos académicos y de escalabilidad, Unibooks implementa una **Arquitectura de Persistencia Políglota (Híbrida)**:

```
+---------------------------------------------------------------------------------------+
|                                      CAPA DE DATOS                                    |
|   +------------------------------------+    +-------------------------------------+   |
|   |   BASE DE DATOS RELACIONAL (RDBMS) |    |      MOTOR EN TIEMPO REAL (NoSQL)   |   |
|   |         PostgreSQL (Supabase)      |    |          Firebase Firestore         |   |
|   |  - Catálogo de Libros (CRUD)       |    |  - Mensajería Directa (WhatsApp)    |   |
|   |  - Búsqueda Full-Text con unaccent |    |  - Streams de Mensajes de Texto     |   |
|   |  - Sedes, Carreras y Campus UDEC   |    |  - Fotos instantáneas en Chat       |   |
|   |  - Transacciones y PIN de Entrega  |    |  - Estado de lectura y presencia    |   |
|   |  - Triggers de Reputación Promedio |    |  - Seguridad por Reglas Firestore   |   |
|   +------------------------------------+    +-------------------------------------+   |
|                                                                                       |
|   +-------------------------------------------------------------------------------+   |
|   |                     ALMACENAMIENTO MULTIMEDIA (OBJECT STORAGE)                |   |
|   |                               Firebase Storage                                |   |
|   |  - Fotos de Perfil (Avatares de Estudiantes)                                  |   |
|   |  - Galería de Fotos de Libros (1 a 4 imágenes de portada y estado físico)     |   |
|   |  - Fotografías enviadas a través de la conversación en tiempo real            |   |
|   +-------------------------------------------------------------------------------+   |
+---------------------------------------------------------------------------------------+
```

---

## 2. Diagrama Entidad-Relación (DER) Relacional - Notación Mermaid

El siguiente diagrama formaliza el modelo relacional implementado en PostgreSQL para el Backend FastAPI:

```mermaid
erDiagram
    SEDES ||--o{ PROGRAMAS_ACADEMICOS : "contiene (seccionales)"
    SEDES ||--o{ PUNTOS_ENCUENTRO : "ubica dentro de campus"
    SEDES ||--o{ USUARIOS : "pertenece a sede principal"
    SEDES ||--o{ PUBLICACIONES : "disponible en sede"
    
    FACULTADES ||--o{ PROGRAMAS_ACADEMICOS : "organiza"
    FACULTADES ||--o{ PUBLICACIONES : "clasifica por area"
    
    PROGRAMAS_ACADEMICOS ||--o{ USUARIOS : "estudia en"
    
    USUARIOS ||--o{ PUBLICACIONES : "publica"
    USUARIOS ||--o{ SOLICITUDES_INTERCAMBIO : "propone (solicitante)"
    USUARIOS ||--o{ SOLICITUDES_INTERCAMBIO : "recibe propuesta (receptor)"
    USUARIOS ||--o{ TRANSACCIONES : "vende o dona (vendedor)"
    USUARIOS ||--o{ TRANSACCIONES : "reserva o adquiere (comprador)"
    USUARIOS ||--o{ CALIFICACIONES : "emite evaluacion (evaluador)"
    USUARIOS ||--o{ CALIFICACIONES : "recibe evaluacion (evaluado)"
    USUARIOS ||--o{ NOTIFICACIONES : "recibe"

    PUBLICACIONES ||--o{ FOTOS_PUBLICACION : "posee galeria (1-4 fotos)"
    PUBLICACIONES ||--o{ SOLICITUDES_INTERCAMBIO : "objeto de trueque"
    PUBLICACIONES ||--o{ TRANSACCIONES : "se formaliza en"

    PUNTOS_ENCUENTRO ||--o{ TRANSACCIONES : "sitio fisico de entrega"
    SOLICITUDES_INTERCAMBIO ||--o| TRANSACCIONES : "formaliza acuerdo trueque"
    TRANSACCIONES ||--o{ CALIFICACIONES : "respalda resenas mutuas"

    SEDES {
        uuid id PK
        varchar nombre UK "Nombre oficial de sede UDEC"
        varchar ciudad "Municipio de Cundinamarca"
        varchar direccion "Ubicacion fisica"
        boolean activo
    }

    FACULTADES {
        uuid id PK
        varchar nombre UK "Nombre formal de facultad"
        varchar sigla "FING, FCAEC, etc."
        boolean activo
    }

    PROGRAMAS_ACADEMICOS {
        uuid id PK
        uuid facultad_id FK
        varchar nombre "Carrera universitaria"
        varchar codigo_snies
        boolean activo
    }

    PUNTOS_ENCUENTRO {
        uuid id PK
        uuid sede_id FK
        varchar nombre "Ej. Biblioteca Central"
        text descripcion "Zona iluminada y vigilada"
        varchar referencia_visual "Lobby de Biblioteca"
        boolean activo
    }

    USUARIOS {
        uuid id PK
        varchar firebase_uid UK "Identificador unico de Firebase Auth"
        varchar email UK "Check regex @ucundinamarca.edu.co"
        varchar nombre_completo
        varchar telefono "WhatsApp de contacto"
        text avatar_url "Firebase Storage URL"
        uuid sede_principal_id FK
        uuid programa_id FK
        rol_usuario_enum rol "ESTUDIANTE, DOCENTE, ADMIN"
        estado_usuario_enum estado "ACTIVO, SUSPENDIDO"
        numeric reputacion_promedio "1.00 a 5.00 calculado por trigger"
        int total_calificaciones
        varchar biografia
    }

    PUBLICACIONES {
        uuid id PK
        uuid usuario_id FK "Estudiante que oferta"
        varchar titulo "Titulo del libro"
        varchar autor "Autor(es)"
        varchar editorial
        varchar edicion
        int ano_publicacion
        varchar isbn
        varchar materia "Asignatura academica"
        smallint semestre_sugerido "1 a 10"
        uuid facultad_id FK
        uuid sede_id FK
        condicion_libro_enum condicion_libro "NUEVO, BUEN_ESTADO, etc."
        modalidad_publicacion_enum modalidad "VENTA, INTERCAMBIO, DONACION"
        numeric precio ">= 0.00 COP"
        text descripcion
        text interes_intercambio "Libros que busca a cambio"
        estado_publicacion_enum estado "DISPONIBLE, RESERVADO, VENDIDO"
        int vistas
        tsvector tsv_busqueda "Indice vectorial con unaccent"
    }

    FOTOS_PUBLICACION {
        uuid id PK
        uuid publicacion_id FK
        text foto_url "Firebase Storage URL"
        boolean es_portada
        smallint orden "1 a 4"
    }

    SOLICITUDES_INTERCAMBIO {
        uuid id PK
        uuid publicacion_solicitada_id FK
        uuid publicacion_ofrecida_id FK "Libro entregado en trueque"
        uuid usuario_solicitante_id FK
        uuid usuario_receptor_id FK
        text mensaje_propuesta
        estado_intercambio_enum estado "PENDIENTE, ACEPTADA, RECHAZADA"
        timestamptz fecha_respuesta
        text motivo_rechazo
    }

    TRANSACCIONES {
        uuid id PK
        uuid publicacion_id FK
        uuid solicitud_intercambio_id FK
        uuid vendedor_id FK
        uuid comprador_id FK
        tipo_transaccion_enum tipo_transaccion "VENTA, INTERCAMBIO, DONACION"
        numeric monto_pago "0 si es trueque o donacion"
        uuid punto_encuentro_id FK "Lugar seguro en el campus"
        timestamptz fecha_hora_encuentro
        varchar codigo_verificacion_entrega "PIN 6 digitos antifraude"
        estado_transaccion_enum estado "PENDIENTE_ENCUENTRO, COMPLETADA"
        boolean confirmado_vendedor
        boolean confirmado_comprador
        text observaciones_entrega
        timestamptz fecha_completada
    }

    CALIFICACIONES {
        uuid id PK
        uuid transaccion_id FK
        uuid evaluador_id FK
        uuid evaluado_id FK
        smallint puntuacion "1 a 5 estrellas"
        text comentario
        smallint puntualidad "1 a 5"
        smallint estado_libro_fiel "1 a 5"
    }

    NOTIFICACIONES {
        uuid id PK
        uuid usuario_id FK
        tipo_notificacion_enum tipo
        varchar titulo
        text mensaje
        uuid referencia_id
        varchar tipo_referencia
        boolean leida
    }
```

---

## 3. Esquema NoSQL en Firebase Firestore (Motor de Chat en Tiempo Real)

Para lograr la experiencia interactiva estilo WhatsApp con actualización instantánea (<100ms) y compartición de fotos, se diseñó la siguiente jerarquía de colecciones en Firestore:

### 3.1. Colección `/chats/{chatId}`
* **Identificador de documento (`chatId`):** Generado de forma determinista para evitar conversaciones duplicadas:
  `{publicacionId}_{compradorUid}_{vendedorUid}`
* **Estructura del Documento:**
```json
{
  "chatId": "66666666-6666-6666-6666-666666666601_carlos_maria",
  "publicacionId": "66666666-6666-6666-6666-666666666601",
  "tituloLibro": "Cálculo: Trascendentes Tempranas",
  "portadaLibroUrl": "https://firebasestorage.googleapis.com/.../calculo.jpg",
  "precioLibro": 65000.0,
  "modalidadLibro": "VENTA_O_INTERCAMBIO",
  "participantes": ["fb_uid_carlos_02", "fb_uid_maria_03"],
  "compradorUid": "fb_uid_maria_03",
  "vendedorUid": "fb_uid_carlos_02",
  "compradorNombre": "María Paula Rodríguez",
  "vendedorNombre": "Carlos Mendoza Vargas",
  "compradorAvatarUrl": "https://firebasestorage.googleapis.com/.../maria.jpg",
  "vendedorAvatarUrl": "https://firebasestorage.googleapis.com/.../carlos.jpg",
  "ultimoMensajeTexto": "¿Podrías enviarme una foto de la tabla de integrales?",
  "ultimoMensajeTipo": "TEXT",
  "ultimoMensajeTimestamp": "2026-10-15T12:00:00Z",
  "ultimoMensajeRemitenteUid": "fb_uid_maria_03",
  "noLeidosPorUsuario": {
    "fb_uid_carlos_02": 1,
    "fb_uid_maria_03": 0
  },
  "creadoEn": "2026-10-15T11:45:00Z",
  "activo": true
}
```

### 3.2. Subcolección `/chats/{chatId}/messages/{messageId}`
Cada mensaje enviado se registra como un documento inmutable dentro de la subcolección del chat:
```json
{
  "messageId": "msg_uuid_0001",
  "remitenteUid": "fb_uid_carlos_02",
  "remitenteNombre": "Carlos Mendoza Vargas",
  "texto": "Claro que sí, mira cómo está la tabla de fórmulas:",
  "fotoUrl": "https://firebasestorage.googleapis.com/.../chats/msg_foto_01.jpg",
  "tipo": "IMAGE", // "TEXT" o "IMAGE"
  "timestamp": "2026-10-15T12:01:23Z",
  "leido": true
}
```

### 3.3. Índices Compuestos Requeridos en Firestore
* Colección `chats`: `participantes` (Array-contains) + `ultimoMensajeTimestamp` (Descending) para ordenar las conversaciones recientes en la bandeja de entrada.
* Subcolección `messages`: `timestamp` (Ascending) para renderizar el flujo cronológico de mensajes.

---

## 4. Estructura de Almacenamiento en Firebase Storage

```
gs://unibooks-udec.appspot.com/
├── avatars/
│   └── {userId}/
│       └── profile.jpg                 # Foto de perfil del estudiante
├── publications/
│   └── {publicationId}/
│       ├── photo_1.jpg                 # Foto de portada principal
│       ├── photo_2.jpg                 # Detalle de lomo o encuadernación
│       └── photo_3.jpg                 # Muestra de páginas interiores
└── chats/
    └── {chatId}/
        └── {imageUuid}.jpg             # Fotografías enviadas por el chat en vivo
```

---

## 5. Reglas de Seguridad Implementadas

1. **PostgreSQL:**
   * Restricción CHECK de correo: `chk_email_institucional CHECK (email ~* '^[A-Za-z0-9._%+-]+@ucundinamarca\.edu\.co$')`.
   * Restricción de calificación: `CHECK (puntuacion >= 1 AND puntuacion <= 5)`.
   * Trigger atómico `trg_actualizar_reputacion_usuario` para evitar inconsistencias en el cálculo de estrellas.
2. **Firestore (`database/firestore.rules`):**
   * Validación del token JWT de Firebase con expresión regular para el dominio `@ucundinamarca.edu.co`.
   * Verificación de pertenencia al array de `participantes` antes de permitir lectura o escritura de mensajes.
3. **Storage (`database/storage.rules`):**
   * Verificación de tipo MIME `image/*` y tamaño máximo de 5MB por imagen.
   * Escritura en la carpeta `/avatars/{userId}/` restringida estrictamente al propio usuario dueño del UID.
