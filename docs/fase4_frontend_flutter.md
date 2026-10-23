# FASE 4: CLIENTE FRONTEND MULTIPLATAFORMA EN FLUTTER (MÓVIL Y WEB)
## Proyecto de Grado: "Unibooks: Plataforma para compra, venta e intercambio de libros para la Universidad de Cundinamarca"

---

## 1. Visión y Arquitectura del Frontend

El cliente de **Unibooks** fue desarrollado en **Flutter (Dart 3.13+)**, diseñado bajo los principios de **Clean Architecture** y una gestión de estado reactiva con **Provider**. El proyecto compila de forma nativa para **Android (APK)** y **Web (HTML/CanvasKit/Wasm)**, ofreciendo una experiencia responsiva y adaptada a la identidad institucional de la Universidad de Cundinamarca (UDEC).

```
+---------------------------------------------------------------------------------------+
|                      ESTRUCTURA DE ARQUITECTURA FRONTEND FLUTTER                      |
+---------------------------------------------------------------------------------------+
|                                                                                       |
|  [CAPA DE PRESENTACIÓN]                                                               |
|  ├── screens/                                                                         |
|  │   ├── catalog/ (Catálogo responsivo + Detalle con galería de 1 a 4 fotos)         |
|  │   ├── chat/ (Bandeja Inbox + Detalle WhatsApp con visor interactivo Zoom/Pan)     |
|  │   ├── trades/ (Gestión de trueques + Validación PIN + Calificaciones con estrellas)|
|  │   ├── publications/ (Formulario validado con selector de fotos de ejemplar)       |
|  │   ├── profile/ (Perfil de estudiante + Cambiador ágil de perfiles dev)             |
|  │   └── auth/ (Inicio de sesión con correo @ucundinamarca.edu.co)                    |
|  │                                                                                    |
|  [CAPA DE ESTADO Y NEGOCIO]                                                           |
|  ├── providers/                                                                       |
|  │   ├── AuthProvider (Gestión de sesión JWT y perfiles institucionales)              |
|  │   ├── CatalogProvider (Filtros por sede, modalidad, búsqueda y paginación)         |
|  │   ├── TradeProvider (Propuestas, confirmación PIN y evaluación de reputación)      |
|  │   └── ChatProvider (Mensajes en tiempo real, conteo de no leídos y multimedia)     |
|  │                                                                                    |
|  [CAPA DE DOMINIO Y DATOS]                                                            |
|  ├── models/                                                                          |
|  │   ├── UserModel, PublicationModel, TradeModel, TransactionModel, ChatModel         |
|  │                                                                                    |
|  [CAPA CORE Y INFRAESTRUCTURA]                                                        |
|  ├── core/                                                                            |
|  │   ├── constants/ (AppColors UDEC, ApiEndpoints responsivos según host)             |
|  │   ├── network/ (ApiClient HTTP con interceptores JWT y manejo de excepciones)      |
|  │   └── theme/ (AppTheme institucional con paleta verde bosque y dorado)            |
+---------------------------------------------------------------------------------------+
```

---

## 2. Módulos y Funcionalidades Clave

### 2.1. Catálogo Institucional Avanzado (`CatalogScreen`)
* **Barra de Búsqueda:** Búsqueda en tiempo real por título, autor, asignatura académica o código ISBN.
* **Filtros por Sede UDEC:** Selector horizontal dinámico con las sedes oficiales (Fusagasugá, Girardot, Facatativá, Ubaté, Chía, Soacha, Zipaquirá y Chocontá).
* **Filtros por Modalidad:** Segmentación por Venta, Trueque y Donación.
* **Barra de Resultados y Restablecimiento:** Conteo en tiempo real de ejemplares disponibles y botón de un clic para restablecer filtros.
* **Cuadrícula Adaptativa (GridView):**
  - Pantallas móviles (<600px): 2 columnas.
  - Tablets (600px - 900px): 3 columnas.
  - Escritorio / Web (>900px): 4 columnas con proporciones de tarjeta enriquecida.

### 2.2. Detalle del Libro y Galería Multimedia (`BookDetailScreen`)
* **Galería Interactiva:** Soporte de 1 a 4 fotografías (carátula, detalle de páginas, lomo y encuadernación) con selector de miniaturas táctil.
* **Tarjeta del Vendedor:** Avatar institucional, nombre completo, correo `@ucundinamarca.edu.co` y calificación promedio con estrellas Likert y total de reseñas.
* **Acciones Contextuales:**
  - Botón principal de **"Contactar por Chat (WhatsApp UDEC)"**.
  - Botón **"Proponer Trueque"** con selector modal de libros propios para intercambio.
  - Botón **"Reservar Libro"** con selección de punto seguro de entrega en el campus y fecha acordada.

### 2.3. Módulo de Trueques, PIN de Entrega y Calificaciones (`TradesScreen`)
* **Pestaña Recibidas:** Lista de solicitudes de trueque con opción de Aceptar o Rechazar (indicando motivo).
* **Pestaña Enviadas:** Seguimiento en tiempo real del estado de propuestas (PENDIENTE, ACEPTADA, RECHAZADA).
* **Pestaña Entregas en Campus:**
  - Visualización del punto de encuentro seguro asignado (ej. Biblioteca Central, Cafetería Principal).
  - PIN de seguridad antifraude de 6 dígitos.
  - Botón **"Validar PIN"**: al confirmarse la entrega, se completa la transacción y **se abre automáticamente el diálogo de calificación**.
* **Diálogo de Calificación con Estrellas:**
  - Puntuación general de 1 a 5 estrellas.
  - Sliders para evaluar puntualidad en el campus y fidelidad del estado del libro.
  - Campo de comentario cualitativo.
  - Actualización atómica en base de datos mediante triggers PostgreSQL.

### 2.4. Publicación de Libros con Galería (`CreatePublicationScreen`)
* Selector dinámico de Sedes UDEC y Facultades.
* Selección de condición física (`NUEVO`, `COMO_NUEVO`, `BUEN_ESTADO`, `ACEPTABLE`, `DESGASTADO`).
* Gestor de Fotografías (1 a 4 fotos): permite agregar fotografías con vista previa de miniaturas, etiqueta automática de portada y botón para remover imágenes.
* Validación estricta de formularios y precios según modalidad.

### 2.5. Perfil Institucional y Cambiador de Cuentas (`ProfileScreen`)
* Estadísticas del estudiante: reputación promedio y calificaciones recibidas.
* **Cambiador de Perfiles para Sustentación:** Permite alternar con un toque entre:
  - `Carlos Mendoza` (Estudiante de Ingeniería de Sistemas - Fusagasugá).
  - `María Paula Rodríguez` (Estudiante de Administración - Girardot).
  - `Administrador General` (Control institucional).
  Al cambiar de perfil, la aplicación actualiza automáticamente el catálogo, los trueques y las conversaciones del usuario activo.

---

## 3. Adaptabilidad Multiplataforma (Móvil vs Web)

La interfaz se adapta fluidamente según la resolución y plataforma del dispositivo (`LayoutBuilder`):
* **Web / Pantallas Anchas (≥800px):** Menú lateral persistente `NavigationRail` con logotipo institucional y badges de notificaciones de mensajes.
* **Móvil / Pantallas Angostas (<800px):** Barra inferior táctil `NavigationBar` con 5 destinos: Catálogo, Trueques, Mensajes, Publicar y Perfil.
