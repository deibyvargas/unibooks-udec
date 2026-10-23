# GUÍA DE SUSTENTACIÓN Y DEFENSA DEL PROYECTO DE GRADO
## Proyecto: "Unibooks: Plataforma para compra, venta e intercambio de libros para la Universidad de Cundinamarca"

---

## 1. Justificación del Problema y Relevancia Institucional

La **Universidad de Cundinamarca (UDEC)** cuenta con una estructura multicampus distribuida a lo largo del departamento (Sede Principal en Fusagasugá, Seccionales en Girardot y Ubaté, y Extensiones en Facatativá, Chía, Soacha, Chocontá y Zipaquirá). 

### Problemáticas Detectadas:
1. **Barrera Económica:** El costo de los libros técnicos y científicos nuevos (ingenierías, ciencias agropecuarias, ciencias de la salud) oscila entre $80.000 y $250.000 COP, impactando negativamente la permanencia estudiantil.
2. **Subutilización de Material Bibliográfico:** Al finalizar cada semestre académico, miles de ejemplares en excelente estado quedan en desuso en los hogares de los estudiantes.
3. **Inseguridad y Falta de Canales Formales:** Las compras informales en redes sociales carecen de verificación institucional, exponen a fraudes y a encuentros en zonas no vigiladas.

**Solución aportada por Unibooks:** Un ecosistema digital formal, exclusivo para correos `@ucundinamarca.edu.co`, que fomenta la **economía circular académica**, habilita el modelo de **trueque libro-por-libro**, establece **puntos de entrega seguros dentro de los campus** y valida las transacciones mediante un **código PIN antifraude**.

---

## 2. Argumentación Técnica de Decisiones de Arquitectura

Ante las preguntas de los jurados evaluadores, utiliza los siguientes argumentos de ingeniería de software:

| Componente | Elección Tecnológica | Justificación de Ingeniería |
| :--- | :--- | :--- |
| **Backend** | Python con **FastAPI** | Rendimiento asíncrono superior (ASGI), tipado estricto con **Pydantic V2** y generación nativa y automática de documentación interactiva **OpenAPI / Swagger**. |
| **Base de Datos** | **PostgreSQL** (3ra Forma Normal) | Garantía de integridad referencial ACID, triggers automáticos para el cálculo de reputación y búsqueda avanzada en español mediante vector **GIN** con soporte de `unaccent`. |
| **Frontend** | **Flutter (Dart)** | Desarrollo de una sola base de código con arquitectura modular (Provider / Clean Architecture) que compila nativamente para **Android Móvil** y **Web**. |
| **Autenticación** | **Firebase Auth** | Seguridad estándar de la industria basada en tokens JWT, reforzada por middleware que valida el dominio `@ucundinamarca.edu.co`. |
| **Seguridad Física** | **Puntos de Encuentro + PIN** | Mitigación del riesgo de seguridad física; ambas partes acuerdan verse en zonas vigiladas del campus (bibliotecas, recepciones) y validan la entrega con un token de 6 dígitos. |
| **Analítica** | **Streamlit + Plotly** | Capacidad de visualización interactiva y reactiva de datos masivos (EDA), ofreciendo a las directivas métricas de ahorro y demanda bibliográfica. |

---

## 3. Guion de Demostración en Vivo (Live Demo - 5 Minutos)

Sigue esta secuencia exacta durante la presentación para impresionar a los jurados:

### Minuto 1: Acceso Institucional y Perfiles
* Abre la aplicación en Flutter (Web o Android).
* Muestra el mensaje de restricción: solo correos `@ucundinamarca.edu.co`.
* Utiliza el selector de perfiles para ingresar como **Carlos Mendoza** (Estudiante de Ingeniería de Sistemas en Fusagasugá).
* Muestra la reputación del estudiante (⭐ 4.90 / 5.0).

### Minuto 2: Exploración de Catálogo y Búsqueda Avanzada
* Demuestra la búsqueda instantánea escribiendo *"Stewart"* o *"Cálculo"*.
* Filtra por Sede (ej. *Fusagasugá* vs *Girardot*).
* Muestra las etiquetas visuales de modalidad: **Venta**, **Trueque** y **Donación**.

### Minuto 3: Propuesta de Intercambio (Match Libro-por-Libro)
* Cambia de perfil a **María Paula Rodríguez** (Girardot).
* Selecciona un libro y haz clic en **"Proponer Trueque"**.
* Escribe una propuesta (ej. *"Te ofrezco mi libro de Macroeconomía por tu libro de Cálculo"*).
* Cambia de nuevo a Carlos Mendoza: muestra la pestaña de **Trueques Recibidos** y haz clic en **"Aceptar Trueque"**.

### Minuto 4: Reserva y Validación Segura por PIN en Campus
* Muestra la reserva en el punto seguro: **"Biblioteca Central - Entrada Principal"**.
* Enseña el código **PIN de 6 dígitos** generado por el sistema.
* Confirma la entrega ingresando el PIN: el libro cambia de estado a `COMPLETADO` / `INTERCAMBIADO`.

### Minuto 5: Dashboard de Analítica e Impacto Social (Streamlit)
* Cambia de pantalla y proyecta el Dashboard en `http://localhost:8501`.
* Muestra los **4 KPIs de Impacto Social**:
  - Más de **$31.2 Millones de COP en ahorro estimado** para los estudiantes.
  - Más del **55%** de participación en modalidades solidarias (Trueque y Donación).
* Alterna entre **Modo Claro** y **Modo Oscuro**.
* Filtra por Facultad de Ingeniería y descarga el reporte en formato CSV.

---

## 4. Respuestas a Preguntas Típicas del Jurado

* **Pregunta:** *¿Cómo garantizan que solo miembros de la universidad utilicen la plataforma?*
  * **Respuesta:** Implementamos una doble barrera de seguridad: primero, a nivel de backend y middleware (`app/core/security.py`), se rechaza cualquier token de correo que no termine en `@ucundinamarca.edu.co`. Segundo, a nivel de base de datos relacional, la tabla `usuarios` contiene una restricción formal `CHECK (email ~* '^[A-Za-z0-9._%+-]+@ucundinamarca\.edu\.co$')`.

* **Pregunta:** *¿Qué pasa si un libro tiene tildes o errores ortográficos en la búsqueda?*
  * **Respuesta:** En PostgreSQL configuramos la extensión `unaccent` combinada con un índice vectorial `GIN` y pesos semánticos (`setweight`), permitiendo que búsquedas como "calculo" encuentren libros registrados como "Cálculo", con tiempos de respuesta en milisegundos.

* **Pregunta:** *¿Cómo evitan fraudes en la entrega de los libros físicos?*
  * **Respuesta:** La entrega no se realiza en sitios externos, sino en puntos vigilados dentro del campus universitario previamente registrados (`puntos_encuentro`). Además, la transacción solo se consolida cuando la contraparte suministra el PIN de seguridad de 6 dígitos generado por el sistema.
