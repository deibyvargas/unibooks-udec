# Bases de Datos Avanzadas en Unibooks

Este documento muestra dónde y cómo aplica Unibooks cada tema de Bases de Datos Avanzadas, con referencias al código fuente.

| # | Tema | Dónde está implementado |
|---|---|---|
| 1 | Conectividad Backend (ORM) | `backend/app/core/database.py`, `backend/app/models/entities.py` |
| 1 | Fundamentos de transacciones | `get_db` y `transaction_scope` en `database.py`, endpoints de `transactions.py` |
| 1 | Control de concurrencia | `backend/app/core/concurrency.py`, `transactions.py`, `trade_service.py` |
| 2 | Optimización de consultas | `QueryStats` en `database.py`, `scripts/benchmark_queries.py`, `rating_service.py` |
| 2 | Indexación avanzada | `PERFORMANCE_INDEXES` en `backend/app/db/init_db.py`, sección 15 de `database/unibooks_schema.sql` |
| 3 | NoSQL (documentos) | Cloud Firestore desde Flutter (`frontend/lib/services`, `frontend/lib/providers`), `firestore.rules` |
| 3 | Arquitectura híbrida | PostgreSQL (FastAPI) + Firestore (tiempo real) + Firebase Storage |

---

## 1. Conectividad Backend (ORM)

- **Lenguaje → motor:** Python (FastAPI) se conecta mediante **SQLAlchemy 2.0** (ORM) al driver **psycopg2** de PostgreSQL. En desarrollo y pruebas usa SQLite. El motor se elige con la variable `DATABASE_URL` y el código no cambia.
- **Mapeo objeto-relacional:** cada tabla es una clase en `entities.py` (`Usuario`, `Publicacion`, `Transaccion`…), con `relationship()` para las claves foráneas.
- **Pool de conexiones** (PostgreSQL): `pool_size=10` y `max_overflow=20` (configurables con `DB_POOL_SIZE` y `DB_MAX_OVERFLOW`). Además `pool_pre_ping` descarta conexiones caídas y `pool_recycle=1800` renueva las conexiones cada 30 minutos.
- **Migraciones:** Alembic (incluido en `requirements.txt`).
- **Inyección por petición:** cada request HTTP recibe su propia `Session` mediante `Depends(get_db)`.

## 2. Fundamentos de transacciones (ACID)

- `autocommit=False`: nada se guarda hasta un `COMMIT` explícito.
- **Atomicidad:** `get_db()` hace `ROLLBACK` automático si el endpoint lanza una excepción. Por ejemplo, en `confirmar_entrega` se actualizan la transacción, el libro, las reservas competidoras, las evaluaciones y las notificaciones en **un solo COMMIT**: o se aplica todo o no se aplica nada.
- **Unit of Work:** el context manager `transaction_scope(db)` confirma o deshace un bloque completo. El test `test_transaction_scope_hace_rollback_si_falla` lo comprueba.
- **Consistencia:** restricciones `UNIQUE`, `CHECK` y `FOREIGN KEY` en `unibooks_schema.sql`, más el trigger de reputación.

## 3. Control de concurrencia

Varias personas pueden operar sobre el mismo libro al mismo tiempo. Esta tabla resume cada anomalía y cómo se resuelve:

| Anomalía | Ejemplo en Unibooks | Solución implementada |
|---|---|---|
| **Lectura sucia** (dirty read) | Ver un libro "NO_DISPONIBLE" de una entrega que aún no se confirma | Aislamiento **READ COMMITTED** explícito en PostgreSQL. En SQLite, modo **WAL** |
| **Actualización perdida** (lost update) | Dos visitas simultáneas leen `vistas=10` y ambas escriben 11 | `atomic_increment`: `UPDATE ... SET vistas = vistas + 1` en el motor |
| **Condición de carrera / doble reserva** | Dos compradores reservan el mismo libro, o el dueño acepta dos veces | **Bloqueo pesimista** `SELECT ... FOR UPDATE` (`lock_row`) |
| **Transición de estado duplicada** | Dos confirmaciones de entrega con el mismo PIN | **Control optimista** compare-and-set: `UPDATE ... WHERE estado = 'PENDIENTE_ENCUENTRO'`. Si afecta 0 filas, responde HTTP 409 |
| **Inserciones duplicadas simultáneas** | Calificar dos veces, crear el mismo chat dos veces | Restricción `UNIQUE` + `commit_or_conflict`, que traduce `IntegrityError` a HTTP 409 |
| **Bloqueos (locks) prolongados** | Una fila bloqueada por otra transacción | `busy_timeout` en SQLite, `lock_row(nowait=True)` disponible, y `OperationalError` traducido a HTTP 409 |

Las pruebas están en `backend/tests/test_concurrency.py`. Entre ellas hay 5 hilos con 20 visitas simultáneas en total, que verifican que el contador termina exactamente en 20.

## 4. Optimización de consultas

- **Medición del tiempo de ejecución:** listeners de SQLAlchemy (`before/after_cursor_execute`) cronometran cada consulta. Las que superan `SLOW_QUERY_MS` (200 ms) se registran como lentas.
- **Diagnóstico en vivo (solo ADMINISTRADOR):**
  - `GET /api/v1/admin/base-datos/rendimiento`: estadísticas de consultas, consultas lentas, índices, nivel de aislamiento y estado del pool.
  - `GET /api/v1/admin/base-datos/plan-catalogo`: `EXPLAIN ANALYZE` (PostgreSQL) o `EXPLAIN QUERY PLAN` (SQLite) de la consulta del catálogo.
- **Reducción de complejidad (problema N+1):** los listados usan `joinedload`. Cargar 200 libros con su vendedor y sede pasa de **167 consultas a 1** (ver `docs/resultados_benchmark.md`).
- **Eliminación de redundancias:** el recálculo de reputación hacía dos recorridos de `calificaciones` (`AVG` y `COUNT` por separado). Ahora hace **una sola consulta** con ambas agregaciones. El modelo está normalizado (3FN): sedes, facultades y programas son catálogos referenciados, no texto repetido.

## 5. Indexación avanzada

| Tipo | Ejemplo | Consulta que acelera |
|---|---|---|
| Simple (B-Tree) | `idx_publicaciones_estado` | Filtros por un campo |
| **Compuesto** | `idx_pub_estado_sede_fecha (estado, sede_id, created_at)` | Catálogo por sede ordenado por fecha. El mismo índice resuelve el `WHERE` y el `ORDER BY` |
| **Parcial** | `idx_pub_disponibles_fecha ... WHERE estado = 'DISPONIBLE'` | Solo indexa libros activos: el índice es más pequeño y rápido |
| **GIN (full-text)** | `idx_publicaciones_tsv` | Búsqueda de texto en español |
| **Funcional** | `idx_pub_titulo_lower (LOWER(titulo))` | Búsqueda sin distinguir mayúsculas |
| Único | `uq_transaccion_evaluador` | Integridad y control de concurrencia |

Regla de diseño: **columnas de igualdad primero, columnas de rango u ordenamiento al final.** Los índices se crean automáticamente al arrancar (`ensure_performance_indexes`), de forma idempotente y sin borrar datos.

**Resultados medidos** (20 000 publicaciones; para regenerarlos: `cd backend && python scripts/benchmark_queries.py`):

| Consulta | Sin índices | Con índices | Mejora |
|---|---:|---:|---:|
| Catálogo por sede | 5.66 ms | 0.26 ms | 21.5x |
| Catálogo por precio | 5.76 ms | 0.21 ms | 27.1x |
| Mis publicaciones | 4.01 ms | 0.49 ms | 8.3x |
| Mis transacciones | 1.47 ms | 0.34 ms | 4.3x |
| Notificaciones no leídas | 6.79 ms | 0.48 ms | 14.2x |

El plan de ejecución pasa de `SCAN publicaciones | USE TEMP B-TREE FOR ORDER BY` (recorre toda la tabla y luego ordena) a `SEARCH publicaciones USING INDEX idx_pub_estado_sede_fecha`.

## 6. Bases de datos NoSQL (Cloud Firestore)

Firestore es una base **orientada a documentos**, en la misma familia que MongoDB: **colecciones** que contienen **documentos JSON**, con subcolecciones anidadas.

Unibooks usa estas colecciones: `usuarios`, `publicaciones`, `chats` → `mensajes`, `transacciones`, `solicitudes_intercambio`, `calificaciones` y `notificaciones`.

```
chats/{chatId}                      <- documento
   participantes: [uidA, uidB]
   ultimoMensaje: "¿Nos vemos en la biblioteca?"
   mensajes/{mensajeId}             <- subcolección
      texto, fotoUrl, remitente, timestamp, leido
```

| Ventajas frente al modelo relacional | Limitaciones frente al modelo relacional |
|---|---|
| Esquema flexible: un mensaje puede ser texto o foto sin `ALTER TABLE` | Sin `JOIN`: los datos se desnormalizan (se duplica, por ejemplo, el nombre del usuario) |
| Tiempo real: `snapshots()` envía los cambios al instante (chat) | Transacciones limitadas: no hay transacciones complejas entre muchas colecciones como en SQL |
| Escalado horizontal automático y soporte offline en el móvil | Consultas limitadas: sin agregaciones complejas ni `GROUP BY` arbitrario |
| Lectura de un documento completo en una sola operación | La integridad referencial depende de la aplicación y de `firestore.rules` |
| Seguridad por documento con reglas declarativas | Costo por lectura y escritura. Las consultas compuestas requieren índices declarados |

## 7. Arquitectura híbrida (persistencia políglota)

Cada dato se guarda en el motor que mejor responde a su patrón de uso:

| Dato | Motor | Por qué |
|---|---|---|
| Transacciones, PIN, reservas, calificaciones | **PostgreSQL** | Necesitan ACID, bloqueos, `UNIQUE` y `FOREIGN KEY` |
| Catálogo y búsqueda | **PostgreSQL** | Filtros combinados, índices compuestos y full-text, ordenamientos |
| Sedes, facultades, programas | **PostgreSQL** | Datos maestros normalizados |
| Chat y mensajes | **Firestore** | Tiempo real, esquema flexible, alto volumen de escrituras pequeñas |
| Perfil de usuario y notificaciones en el móvil | **Firestore** | Sincronización instantánea y soporte offline |
| Fotos (libros, avatares, chat) | **Firebase Storage** | Objetos binarios. La base solo guarda la URL |

**Integración:** el usuario se identifica en ambos mundos con el mismo `firebase_uid` (columna `usuarios.firebase_uid` en PostgreSQL = ID del documento en Firestore). Firebase Auth emite el token que valida tanto el backend FastAPI como las reglas de Firestore.

Más detalle del modelo en `docs/fase1_modelado_hibrido.md`.
