# Unibooks: Plataforma para Compra, Venta e Intercambio de Libros
### Universidad de Cundinamarca (UDEC) - Proyecto de Grado

Bienvenido al repositorio central de **Unibooks**. Este sistema provee un ecosistema seguro, académico y colaborativo para estudiantes y docentes de las sedes de Fusagasugá, Girardot, Ubaté, Facatativá, Chía, Soacha, Chocontá y Zipaquirá.

---

## 📁 Estructura del Proyecto

```
PROYECTO 2026/
├── database/                   # [Fase 1] Scripts DDL, normalización y datos semilla
│   └── unibooks_schema.sql     # Script de creación DDL (PostgreSQL / Supabase)
├── backend/                    # [Fase 2] API REST con FastAPI, SQLAlchemy y Pydantic
├── frontend/                   # [Fase 3] Cliente Multiplataforma Flutter (Android / Web)
├── analytics/                  # [Fase 4] Módulo de Análisis Exploratorio (EDA) y Streamlit
└── docs/                       # Documentación formal de arquitectura y sustentación
    └── architecture_and_model.md
```

---

## 🚀 Estado de Avance por Fases

- [x] **Fase 1: Modelado de Datos y Arquitectura Base** (Completada)
  - Diagrama Entidad-Relación (DER) 3NF en Mermaid.
  - Script DDL con PostgreSQL: Tipos ENUM, restricciones de dominio (@ucundinamarca.edu.co), Full-Text Search e Índices GIN/B-tree.
  - Triggers automáticos para auditoría (`updated_at`) y actualización de reputación.
  - Script de datos semilla con las sedes, facultades y puntos de encuentro de la UDEC.
- [x] **Fase 2: Backend con FastAPI** (Completada)
  - Arquitectura multicapa: `app/core`, `app/models`, `app/schemas`, `app/api/v1`, `app/db`.
  - Integración de SQLAlchemy 2.0 y Pydantic V2.
  - Middleware de autenticación Firebase Auth con soporte de tokens de desarrollo y restricción de dominio `@ucundinamarca.edu.co`.
  - Endpoints REST para: Perfil institucional, Sedes y Puntos seguros, Publicaciones y Búsqueda, Solicitudes de Intercambio, Reservas y PIN de seguridad, Calificaciones y Reseñas, Mensajería y Notificaciones.
  - Suite de pruebas automatizadas con `pytest` (9/9 pruebas aprobadas al 100%).
- [x] **Fase 3: Frontend Multiplataforma en Flutter** (Completada)
  - Estructura limpia (Clean Architecture / Provider) compartida para Android y Web.
  - Diseño visual institucional moderno (Material 3, paleta UDEC verde bosque/dorado, Google Fonts Outfit/Inter).
  - Servicio HTTP REST (`ApiClient`) con inyección automática de Bearer tokens.
  - Pantallas de autenticación institucional y perfiles de prueba rápidos.
  - Catálogo de libros interactivo con búsqueda reactiva y filtros multifacéticos (sedes, modalidades).
  - Ficha de detalle de libro con reputación de vendedor, propuesta de trueque libro-por-libro y reserva en punto seguro.
  - Formulario completo de publicación de ejemplares con validaciones de negocio.
  - Módulo de intercambio (trueques recibidos/enviados) y validación de entrega mediante código PIN de seguridad.
  - Navegación responsiva adaptable (`NavigationBar` en Android y `NavigationRail` en Web).
- [x] **Fase 4: Análisis Exploratorio de Datos (EDA) y Dashboard con Streamlit** (Completada)
  - Script de procesamiento analítico estadístico (`analytics/eda_analysis.py`).
  - Dashboard interactivo multipestaña en Streamlit (`analytics/dashboard.py`):
    - Conmutador de Modo Claro / Modo Oscuro.
    - 4 Tarjetas de Métricas (KPIs): Libros registrados, Ahorro estudiantil acumulado ($31.2M COP), % Trueque/Donación (55.6%), Tasa de consolidación (61.3%).
    - Filtros dinámicos por Sede de la UDEC, Facultad y Modalidad.
    - Gráficos interactivos en Plotly: Distribución multisede, rotación por semestres, dispersión de precios, comparativa Unibooks vs. librerías comerciales y satisfacción en puntos seguros.
    - Explorador tabular de datos con descarga en CSV.
- [x] **Fase 5: Despliegue en la Nube y Pruebas de Calidad** (Completada)
  - Dockerfiles para Backend FastAPI y Dashboard Streamlit.
  - Orquestación local y de servidor con `docker-compose.yml`.
  - Manifiesto de Infraestructura como Código (`render.yaml`) para Render.com.
  - Guía oficial de despliegue en la nube en [`docs/deployment_and_cloud_guide.md`](./docs/deployment_and_cloud_guide.md) (Supabase, Render, Firebase Hosting, APK Android).
  - Guía metodológica para la sustentación y defensa ante jurados evaluadores en [`docs/thesis_defense_guide.md`](./docs/thesis_defense_guide.md).

---

## 📊 Cómo ejecutar el Dashboard de Analítica (Fase 4)

```bash
# Con el entorno virtual activado:
python analytics/run_dashboard.py

# O directamente con Streamlit:
streamlit run analytics/dashboard.py
```
* Acceso interactivo en navegador: **http://localhost:8501**

---

## 📱 Cómo ejecutar el Frontend en Flutter (Fase 3)

```bash
# 1. Ingresar al directorio del frontend
cd frontend

# 2. Ejecutar en el navegador Web (Chrome / Edge):
flutter run -d chrome

# 3. O ejecutar en Emulador / Dispositivo Android:
flutter run -d android
```

---

## 💻 Cómo ejecutar el Backend (Fase 2)

```bash
# 1. Ingresar al directorio del backend
cd backend

# 2. Activar el entorno virtual
# En Windows (PowerShell):
.venv\Scripts\Activate.ps1
# En Linux/macOS:
source .venv/bin/activate

# 3. Iniciar el servidor con recarga en vivo
python run.py
```

* Documentación interactiva Swagger UI: **http://localhost:8000/docs**
* Documentación técnica ReDoc: **http://localhost:8000/redoc**
* Pruebas automáticas: `pytest tests/test_api.py -v`

---

## 🛠️ Cómo ejecutar la Base de Datos (Fase 1)

1. En tu panel de **Supabase** (o PostgreSQL local / Neon):
2. Abre la consola de consultas SQL (**SQL Editor**).
3. Ejecuta primero [`database/unibooks_schema.sql`](./database/unibooks_schema.sql).
4. El backend crea las tablas y carga únicamente los catálogos institucionales necesarios para los formularios. Usuarios y publicaciones se crean exclusivamente desde la aplicación.
