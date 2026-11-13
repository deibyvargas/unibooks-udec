# Resultados del benchmark de consultas

Generado por `backend/scripts/benchmark_queries.py` el 2026-11-12 23:26.
Datos: 20,000 publicaciones, 10,000 transacciones, 40,000 notificaciones, 500 usuarios. Mediana de 30 ejecuciones (SQLite).

## 1. Índices: tiempo de ejecución

| Consulta | Sin índices (ms) | Con índices (ms) | Mejora |
|---|---:|---:|---:|
| Catálogo por sede (filtro + orden por fecha) | 5.658 | 0.263 | 21.5x |
| Catálogo ordenado por precio | 5.762 | 0.212 | 27.1x |
| Mis publicaciones (usuario + fecha) | 4.012 | 0.485 | 8.3x |
| Mis transacciones como comprador | 1.466 | 0.344 | 4.3x |
| Notificaciones no leídas | 6.792 | 0.478 | 14.2x |

## 2. Planes de ejecución (EXPLAIN QUERY PLAN)

**Catálogo por sede (filtro + orden por fecha)**

- Sin índices: `SCAN publicaciones | USE TEMP B-TREE FOR ORDER BY`
- Con índices: `SEARCH publicaciones USING INDEX idx_pub_estado_sede_fecha (estado=? AND sede_id=?)`

**Catálogo ordenado por precio**

- Sin índices: `SCAN publicaciones | USE TEMP B-TREE FOR ORDER BY`
- Con índices: `SEARCH publicaciones USING INDEX idx_pub_estado_precio (estado=?)`

**Mis publicaciones (usuario + fecha)**

- Sin índices: `SCAN publicaciones | USE TEMP B-TREE FOR ORDER BY`
- Con índices: `SEARCH publicaciones USING INDEX idx_pub_usuario_fecha (usuario_id=?)`

**Mis transacciones como comprador**

- Sin índices: `SCAN transacciones | USE TEMP B-TREE FOR ORDER BY`
- Con índices: `SEARCH transacciones USING INDEX idx_tx_comprador_fecha (comprador_id=?)`

**Notificaciones no leídas**

- Sin índices: `SCAN notificaciones | USE TEMP B-TREE FOR ORDER BY`
- Con índices: `SEARCH notificaciones USING INDEX idx_notif_usuario_leida_fecha (usuario_id=? AND leida=?)`

## 3. Reducción de complejidad: problema N+1

Cargar 200 publicaciones y mostrar su vendedor y sede:

| Estrategia | Consultas SQL | Tiempo (ms) |
|---|---:|---:|
| Carga perezosa (N+1) | 167 | 124.15 |
| joinedload (1 consulta) | 1 | 74.45 |
