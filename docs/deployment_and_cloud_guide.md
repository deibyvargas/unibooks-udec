# GUÍA OFICIAL DE DESPLIEGUE EN LA NUBE (CLOUD DEPLOYMENT)
## Proyecto de Grado: "Unibooks: Plataforma para compra, venta e intercambio de libros para la Universidad de Cundinamarca"

---

## 1. Arquitectura de Despliegue en la Nube

El ecosistema de **Unibooks** utiliza una arquitectura Serverless y PaaS de bajo costo y alta disponibilidad:

* **Base de Datos Relacional:** PostgreSQL alojado en **Supabase** (o Neon).
* **Backend API REST:** Contenedor Docker de FastAPI desplegado en **Render** (o Google Cloud Run).
* **Frontend Móvil (Android):** Paquete APK firmado generado con **Flutter**.
* **Frontend Web:** Compilado Web desplegado en **Firebase Hosting**.
* **Almacenamiento Multimedia y Auth:** **Firebase Storage** y **Firebase Authentication**.
* **Módulo de Analítica y EDA:** **Render** o **Streamlit Community Cloud**.

---

## 2. Paso a Paso: Base de Datos en Supabase (PostgreSQL)

1. Ingresa a [https://supabase.com/](https://supabase.com/) y crea un proyecto gratuito (ej. `unibooks-udec-db`).
2. Define una contraseña segura para el usuario `postgres` y selecciona la región más cercana (ej. `us-east-1`).
3. Ve a la sección **SQL Editor** en la barra lateral izquierda.
4. Abre y copia el contenido completo del archivo:
   - [`database/unibooks_schema.sql`](../database/unibooks_schema.sql)
   - Haz clic en **RUN** para crear las extensiones, tipos ENUM, tablas, claves foráneas, índices GIN y triggers.
5. Abre y copia el contenido de:
   - Haz clic en **RUN** para insertar las 8 sedes reales de la UDEC, facultades, carreras, puntos de encuentro seguros y datos iniciales de prueba.
6. Ve a **Project Settings -> Database** y copia el **Connection String (URI)** con formato:
   ```
   postgresql://postgres:[TU_PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres
   ```

---

## 3. Paso a Paso: Backend FastAPI en Render

1. Sube tu proyecto a un repositorio de **GitHub** o **GitLab**.
2. Ingresa a [https://render.com/](https://render.com/) e inicia sesión con GitHub.
3. Haz clic en **New + -> Web Service**.
4. Conecta tu repositorio del proyecto.
5. Configura los siguientes parámetros:
   - **Name:** `unibooks-backend-api`
   - **Region:** `Oregon (US West)`
   - **Root Directory:** `backend`
   - **Environment:** `Docker`
   - **Plan:** `Free`
6. En la sección **Environment Variables**, añade:
   - `ENVIRONMENT` = `production`
   - `PROJECT_NAME` = `Unibooks API - Universidad de Cundinamarca`
   - `DATABASE_URL` = *(El connection string copiado de Supabase en el paso anterior)*
   - `FIREBASE_DEV_MODE` = `True` (o carga tu archivo de credenciales de Firebase)
   - `INSTITUTIONAL_EMAIL_DOMAIN` = `ucundinamarca.edu.co`
   - `BACKEND_CORS_ORIGINS` = `["*"]`
7. Haz clic en **Create Web Service**. Render compilará el `Dockerfile` y te entregará una URL pública segura HTTPS:
   ```
   https://unibooks-backend-api.onrender.com/docs
   ```

---

## 4. Paso a Paso: Frontend Web en Firebase Hosting

1. Asegúrate de tener instalado el CLI de Firebase:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
2. Compila el bundle web de producción de Flutter:
   ```bash
   cd frontend
   flutter build web --release
   ```
3. Inicializa Firebase Hosting en la carpeta `frontend`:
   ```bash
   firebase init hosting
   ```
   - Selecciona tu proyecto institucional de Firebase.
   - En la pregunta `What do you want to use as your public directory?`, escribe: `build/web`
   - En `Configure as a single-page app (rewrite all urls to /index.html)?`, escribe: `Yes`
   - En `Set up automatic builds and deploys with GitHub?`, escribe: `No`
4. Despliega la aplicación web:
   ```bash
   firebase deploy --only hosting
   ```
5. Firebase te entregará un dominio público instantáneo:
   ```
   https://unibooks-udec.web.app
   ```

---

## 5. Paso a Paso: Compilación del APK para Android

Para generar el instalador en dispositivos físicos o emuladores:

```bash
cd frontend
flutter build apk --release
```
* El archivo instalable se generará en:
  `frontend/build/app/outputs/flutter-apk/app-release.apk`
* Puedes transferir este archivo a tu celular Android para la demostración en vivo.

---

## 6. Paso a Paso: Dashboard de Analítica en la Nube

### Opción A: Streamlit Community Cloud (100% Gratuito)
1. Ingresa a [https://share.streamlit.io/](https://share.streamlit.io/) y conecta tu repositorio.
2. Selecciona la ruta del archivo principal: `analytics/dashboard.py`.
3. Haz clic en **Deploy**. Tendrás el observatorio analítico en una URL permanente lista para proyectar a los jurados.

### Opción B: Render (Mediante render.yaml)
* El repositorio incluye el manifiesto [`render.yaml`](../render.yaml) que despliega automáticamente el dashboard como un Web Service complementario.

---

## 7. Despliegue Local Unificado con Docker Compose

Si deseas ejecutar todo el stack en un solo servidor o máquina de demostración:

```bash
# En la raíz del proyecto:
docker compose up -d --build
```
* **Base de Datos PostgreSQL:** `localhost:5432`
* **Backend API REST:** `http://localhost:8000/docs`
* **Dashboard Analítico Streamlit:** `http://localhost:8501`
