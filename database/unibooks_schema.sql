-- ==============================================================================
-- PROYECTO DE GRADO: UNIBOOKS - UNIVERSIDAD DE CUNDINAMARCA (UDEC)
-- SCRIPT DDL: MODELADO DE BASE DE DATOS RELACIONAL (POSTGRESQL)
-- Versión: 1.0.0
-- Motor: PostgreSQL 14+ / Supabase / Neon
-- ==============================================================================

-- 1. EXTENSIONES REQUERIDAS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- 2. TIPOS ENUMERADOS (DOMINIOS CONTROLADOS)
DO $$ BEGIN
    CREATE TYPE rol_usuario_enum AS ENUM (
        'ESTUDIANTE',
        'DOCENTE',
        'ADMINISTRATIVO',
        'ADMIN',
        'ADMINISTRADOR'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE estado_usuario_enum AS ENUM (
        'ACTIVO',
        'SUSPENDIDO',
        'INACTIVO'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE condicion_libro_enum AS ENUM (
        'NUEVO',
        'COMO_NUEVO',
        'BUEN_ESTADO',
        'ACEPTABLE',
        'DESGASTADO'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE modalidad_publicacion_enum AS ENUM (
        'VENTA',
        'INTERCAMBIO',
        'VENTA_O_INTERCAMBIO',
        'DONACION'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE estado_publicacion_enum AS ENUM (
        'DISPONIBLE',
        'RESERVADO',
        'INTERCAMBIADO',
        'VENDIDO',
        'FINALIZADO',
        'CANCELADO'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE estado_intercambio_enum AS ENUM (
        'PENDIENTE',
        'ACEPTADA',
        'RECHAZADA',
        'CANCELADA',
        'COMPLETADA'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE tipo_transaccion_enum AS ENUM (
        'VENTA',
        'INTERCAMBIO',
        'DONACION'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE estado_transaccion_enum AS ENUM (
        'PENDIENTE_ENCUENTRO',
        'CONFIRMADA_POR_VENDEDOR',
        'CONFIRMADA_POR_COMPRADOR',
        'COMPLETADA',
        'CANCELADA'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE tipo_notificacion_enum AS ENUM (
        'OFERTA_INTERCAMBIO',
        'RESPUESTA_INTERCAMBIO',
        'NUEVA_RESERVA',
        'CONFIRMACION_ENTREGA',
        'NUEVA_CALIFICACION',
        'MENSAJE_NUEVO',
        'SISTEMA'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 3. FUNCIÓN Y TRIGGER PARA AUDITORÍA (updated_at)
CREATE OR REPLACE FUNCTION actualizar_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. TABLAS MAESTRAS INSTITUCIONALES (UDEC)

-- Sedes y Seccionales de la Universidad de Cundinamarca
CREATE TABLE IF NOT EXISTS sedes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(100) NOT NULL UNIQUE,
    ciudad VARCHAR(100) NOT NULL,
    direccion VARCHAR(255) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Facultades de la UDEC
CREATE TABLE IF NOT EXISTS facultades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(150) NOT NULL UNIQUE,
    sigla VARCHAR(20),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Programas Académicos asociados a Facultades
CREATE TABLE IF NOT EXISTS programas_academicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facultad_id UUID NOT NULL REFERENCES facultades(id) ON DELETE RESTRICT,
    nombre VARCHAR(150) NOT NULL,
    codigo_snies VARCHAR(20),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_programa_nombre UNIQUE (facultad_id, nombre)
);

-- Puntos de Encuentro Seguros dentro de los campus de la UDEC
CREATE TABLE IF NOT EXISTS puntos_encuentro (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sede_id UUID NOT NULL REFERENCES sedes(id) ON DELETE RESTRICT,
    nombre VARCHAR(120) NOT NULL,
    descripcion TEXT NOT NULL,
    referencia_visual VARCHAR(255),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_sede_punto UNIQUE (sede_id, nombre)
);

-- 5. TABLA DE USUARIOS INSTITUCIONALES
CREATE TABLE IF NOT EXISTS usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(128) NOT NULL UNIQUE,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255),
    nombre_completo VARCHAR(150) NOT NULL,
    telefono VARCHAR(20),
    avatar_url TEXT,
    sede_principal_id UUID REFERENCES sedes(id) ON DELETE SET NULL,
    programa_id UUID REFERENCES programas_academicos(id) ON DELETE SET NULL,
    rol rol_usuario_enum NOT NULL DEFAULT 'ESTUDIANTE',
    estado estado_usuario_enum NOT NULL DEFAULT 'ACTIVO',
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    reputacion_promedio NUMERIC(3,2) NOT NULL DEFAULT 5.00 CHECK (reputacion_promedio >= 1.00 AND reputacion_promedio <= 5.00),
    total_calificaciones INT NOT NULL DEFAULT 0 CHECK (total_calificaciones >= 0),
    biografia VARCHAR(300),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_email_institucional CHECK (email ~* '^[A-Za-z0-9._%+-]+@ucundinamarca\.edu\.co$')
);

-- 6. TABLA DE PUBLICACIONES DE LIBROS
CREATE TABLE IF NOT EXISTS publicaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    titulo VARCHAR(200) NOT NULL,
    autor VARCHAR(150) NOT NULL,
    editorial VARCHAR(100),
    edicion VARCHAR(50),
    ano_publicacion INT CHECK (ano_publicacion >= 1800 AND ano_publicacion <= EXTRACT(YEAR FROM CURRENT_DATE) + 1),
    isbn VARCHAR(20),
    materia VARCHAR(150),
    semestre_sugerido SMALLINT CHECK (semestre_sugerido >= 1 AND semestre_sugerido <= 10),
    facultad_id UUID REFERENCES facultades(id) ON DELETE SET NULL,
    sede_id UUID NOT NULL REFERENCES sedes(id) ON DELETE RESTRICT,
    condicion_libro condicion_libro_enum NOT NULL DEFAULT 'BUEN_ESTADO',
    modalidad modalidad_publicacion_enum NOT NULL DEFAULT 'VENTA_O_INTERCAMBIO',
    precio NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (precio >= 0.00),
    descripcion TEXT NOT NULL,
    interes_intercambio TEXT,
    estado estado_publicacion_enum NOT NULL DEFAULT 'DISPONIBLE',
    vistas INT NOT NULL DEFAULT 0 CHECK (vistas >= 0),
    tsv_busqueda TSVECTOR,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_precio_modalidad CHECK (
        (modalidad = 'DONACION' AND precio = 0.00) OR
        (modalidad = 'INTERCAMBIO' AND precio = 0.00) OR
        (modalidad IN ('VENTA', 'VENTA_O_INTERCAMBIO') AND precio >= 0.00)
    )
);

-- 7. TABLA DE FOTOS MULTIMEDIA DE LIBROS (Firebase Storage)
CREATE TABLE IF NOT EXISTS fotos_publicacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publicacion_id UUID NOT NULL REFERENCES publicaciones(id) ON DELETE CASCADE,
    foto_url TEXT NOT NULL,
    es_portada BOOLEAN NOT NULL DEFAULT FALSE,
    orden SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. TABLA DE PROPUESTAS DE INTERCAMBIO (MATCH/TRUEQUE)
CREATE TABLE IF NOT EXISTS solicitudes_intercambio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publicacion_solicitada_id UUID NOT NULL REFERENCES publicaciones(id) ON DELETE CASCADE,
    publicacion_ofrecida_id UUID REFERENCES publicaciones(id) ON DELETE SET NULL,
    usuario_solicitante_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    usuario_receptor_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    mensaje_propuesta TEXT NOT NULL,
    estado estado_intercambio_enum NOT NULL DEFAULT 'PENDIENTE',
    fecha_respuesta TIMESTAMPTZ,
    motivo_rechazo TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_intercambio_usuarios_distintos CHECK (usuario_solicitante_id <> usuario_receptor_id),
    CONSTRAINT chk_intercambio_libros_distintos CHECK (
        publicacion_ofrecida_id IS NULL OR (publicacion_solicitada_id <> publicacion_ofrecida_id)
    )
);

-- 9. TABLA DE TRANSACCIONES Y RESERVAS
CREATE TABLE IF NOT EXISTS transacciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publicacion_id UUID NOT NULL REFERENCES publicaciones(id) ON DELETE RESTRICT,
    solicitud_intercambio_id UUID REFERENCES solicitudes_intercambio(id) ON DELETE SET NULL,
    vendedor_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    comprador_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    tipo_transaccion tipo_transaccion_enum NOT NULL,
    monto_pago NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (monto_pago >= 0.00),
    punto_encuentro_id UUID NOT NULL REFERENCES puntos_encuentro(id) ON DELETE RESTRICT,
    fecha_hora_encuentro TIMESTAMPTZ NOT NULL,
    codigo_verificacion_entrega VARCHAR(6) NOT NULL,
    estado estado_transaccion_enum NOT NULL DEFAULT 'PENDIENTE_ENCUENTRO',
    confirmado_vendedor BOOLEAN NOT NULL DEFAULT FALSE,
    confirmado_comprador BOOLEAN NOT NULL DEFAULT FALSE,
    observaciones_entrega TEXT,
    fecha_completada TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transaccion_usuarios_distintos CHECK (vendedor_id <> comprador_id)
);

-- 10. TABLA DE CALIFICACIONES Y REPUTACIÓN POST-TRANSACCIÓN
CREATE TABLE IF NOT EXISTS calificaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaccion_id UUID NOT NULL REFERENCES transacciones(id) ON DELETE CASCADE,
    evaluador_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    evaluado_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    puntuacion SMALLINT NOT NULL CHECK (puntuacion >= 1 AND puntuacion <= 5),
    comentario TEXT,
    puntualidad SMALLINT CHECK (puntualidad >= 1 AND puntualidad <= 5),
    estado_libro_fiel SMALLINT CHECK (estado_libro_fiel >= 1 AND estado_libro_fiel <= 5),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_calificacion_usuarios_distintos CHECK (evaluador_id <> evaluado_id),
    CONSTRAINT uq_transaccion_evaluador UNIQUE (transaccion_id, evaluador_id)
);

-- 11. TABLA DE CONVERSACIONES Y MENSAJES DE CONTACTO
CREATE TABLE IF NOT EXISTS conversaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publicacion_id UUID REFERENCES publicaciones(id) ON DELETE SET NULL,
    usuario_uno_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    usuario_dos_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    ultimo_mensaje_texto TEXT,
    ultimo_mensaje_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_conversacion_usuarios_distintos CHECK (usuario_uno_id <> usuario_dos_id),
    CONSTRAINT uq_conversacion_participantes UNIQUE (publicacion_id, usuario_uno_id, usuario_dos_id)
);

CREATE TABLE IF NOT EXISTS mensajes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversacion_id UUID NOT NULL REFERENCES conversaciones(id) ON DELETE CASCADE,
    remitente_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    contenido TEXT NOT NULL,
    tipo VARCHAR(10) NOT NULL DEFAULT 'TEXT' CHECK (tipo IN ('TEXT', 'IMAGE')),
    foto_url TEXT,
    leido BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 12. TABLA DE NOTIFICACIONES DEL SISTEMA
CREATE TABLE IF NOT EXISTS notificaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo tipo_notificacion_enum NOT NULL,
    titulo VARCHAR(150) NOT NULL,
    mensaje TEXT NOT NULL,
    referencia_id UUID,
    tipo_referencia VARCHAR(50),
    leida BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 13. TRIGGERS AUTOMÁTICOS DE AUDITORÍA Y BÚSQUEDA

-- Triggers de actualización de updated_at
CREATE TRIGGER trg_sedes_updated_at BEFORE UPDATE ON sedes FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp_updated_at();
CREATE TRIGGER trg_facultades_updated_at BEFORE UPDATE ON facultades FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp_updated_at();
CREATE TRIGGER trg_programas_academicos_updated_at BEFORE UPDATE ON programas_academicos FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp_updated_at();
CREATE TRIGGER trg_puntos_encuentro_updated_at BEFORE UPDATE ON puntos_encuentro FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp_updated_at();
CREATE TRIGGER trg_usuarios_updated_at BEFORE UPDATE ON usuarios FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp_updated_at();
CREATE TRIGGER trg_publicaciones_updated_at BEFORE UPDATE ON publicaciones FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp_updated_at();
CREATE TRIGGER trg_solicitudes_intercambio_updated_at BEFORE UPDATE ON solicitudes_intercambio FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp_updated_at();
CREATE TRIGGER trg_transacciones_updated_at BEFORE UPDATE ON transacciones FOR EACH ROW EXECUTE FUNCTION actualizar_timestamp_updated_at();

-- Función y trigger para actualización de vector de búsqueda de publicaciones
CREATE OR REPLACE FUNCTION actualizar_tsv_publicacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.tsv_busqueda = 
        setweight(to_tsvector('spanish', unaccent(coalesce(NEW.titulo, ''))), 'A') ||
        setweight(to_tsvector('spanish', unaccent(coalesce(NEW.autor, ''))), 'B') ||
        setweight(to_tsvector('spanish', unaccent(coalesce(NEW.materia, ''))), 'C') ||
        setweight(to_tsvector('spanish', unaccent(coalesce(NEW.editorial, ''))), 'D') ||
        setweight(to_tsvector('spanish', unaccent(coalesce(NEW.descripcion, ''))), 'D');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_publicaciones_tsv_busqueda
BEFORE INSERT OR UPDATE ON publicaciones
FOR EACH ROW EXECUTE FUNCTION actualizar_tsv_publicacion();

-- Función y trigger para recalcular la reputación promedio del usuario calificado
CREATE OR REPLACE FUNCTION actualizar_reputacion_usuario()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE usuarios
    SET 
        reputacion_promedio = ROUND((SELECT AVG(puntuacion)::NUMERIC FROM calificaciones WHERE evaluado_id = NEW.evaluado_id), 2),
        total_calificaciones = (SELECT COUNT(*)::INT FROM calificaciones WHERE evaluado_id = NEW.evaluado_id)
    WHERE id = NEW.evaluado_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_reputacion_usuario
AFTER INSERT OR UPDATE ON calificaciones
FOR EACH ROW EXECUTE FUNCTION actualizar_reputacion_usuario();

-- 14. ÍNDICES DE RENDIMIENTO Y OPTIMIZACIÓN
CREATE INDEX IF NOT EXISTS idx_usuarios_firebase_uid ON usuarios(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_sede ON usuarios(sede_principal_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_programa ON usuarios(programa_id);

CREATE INDEX IF NOT EXISTS idx_programas_facultad ON programas_academicos(facultad_id);
CREATE INDEX IF NOT EXISTS idx_puntos_sede ON puntos_encuentro(sede_id);

CREATE INDEX IF NOT EXISTS idx_publicaciones_usuario ON publicaciones(usuario_id);
CREATE INDEX IF NOT EXISTS idx_publicaciones_sede ON publicaciones(sede_id);
CREATE INDEX IF NOT EXISTS idx_publicaciones_facultad ON publicaciones(facultad_id);
CREATE INDEX IF NOT EXISTS idx_publicaciones_estado ON publicaciones(estado);
CREATE INDEX IF NOT EXISTS idx_publicaciones_modalidad ON publicaciones(modalidad);
CREATE INDEX IF NOT EXISTS idx_publicaciones_precio ON publicaciones(precio);
CREATE INDEX IF NOT EXISTS idx_publicaciones_semestre ON publicaciones(semestre_sugerido);
CREATE INDEX IF NOT EXISTS idx_publicaciones_created_at ON publicaciones(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_publicaciones_tsv ON publicaciones USING GIN(tsv_busqueda);

CREATE INDEX IF NOT EXISTS idx_fotos_publicacion ON fotos_publicacion(publicacion_id);

CREATE INDEX IF NOT EXISTS idx_intercambios_solicitante ON solicitudes_intercambio(usuario_solicitante_id);
CREATE INDEX IF NOT EXISTS idx_intercambios_receptor ON solicitudes_intercambio(usuario_receptor_id);
CREATE INDEX IF NOT EXISTS idx_intercambios_publicacion_sol ON solicitudes_intercambio(publicacion_solicitada_id);
CREATE INDEX IF NOT EXISTS idx_intercambios_estado ON solicitudes_intercambio(estado);

CREATE INDEX IF NOT EXISTS idx_transacciones_publicacion ON transacciones(publicacion_id);
CREATE INDEX IF NOT EXISTS idx_transacciones_vendedor ON transacciones(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_transacciones_comprador ON transacciones(comprador_id);
CREATE INDEX IF NOT EXISTS idx_transacciones_estado ON transacciones(estado);
CREATE INDEX IF NOT EXISTS idx_transacciones_punto ON transacciones(punto_encuentro_id);

CREATE INDEX IF NOT EXISTS idx_calificaciones_evaluado ON calificaciones(evaluado_id);
CREATE INDEX IF NOT EXISTS idx_calificaciones_evaluador ON calificaciones(evaluador_id);
CREATE INDEX IF NOT EXISTS idx_calificaciones_transaccion ON calificaciones(transaccion_id);

CREATE INDEX IF NOT EXISTS idx_mensajes_conversacion ON mensajes(conversacion_id);
CREATE INDEX IF NOT EXISTS idx_mensajes_created_at ON mensajes(created_at ASC);

CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario ON notificaciones(usuario_id, leida);
