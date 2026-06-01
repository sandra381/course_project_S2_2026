-- ─── SCHEMA SPVR ──────────────────────────────────────────────────────────────
-- Base de datos: spvr
-- Motor: MySQL 8.0

-- ─── TABLA: usuarios ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario  INT          NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(100) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    rol         VARCHAR(50)  NOT NULL,
    PRIMARY KEY (id_usuario)
);

-- ─── TABLA: trabajos ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trabajos (
    job_id          INT          NOT NULL AUTO_INCREMENT,
    id_usuario      INT          NOT NULL,
    nombre_archivo  VARCHAR(255) NOT NULL,
    estado          VARCHAR(50)  NOT NULL,
    fecha_carga     DATE         NOT NULL,
    csv_s3_key      VARCHAR(500) NOT NULL,
    PRIMARY KEY (job_id),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

-- ─── TABLA: reportes ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reportes (
    id_reporte      INT          NOT NULL AUTO_INCREMENT,
    job_id          INT          NOT NULL,
    periodo         VARCHAR(50)  NOT NULL,
    pdf_s3_key      VARCHAR(500) NOT NULL,
    fecha_generado  DATE         NOT NULL,
    PRIMARY KEY (id_reporte),
    FOREIGN KEY (job_id) REFERENCES trabajos(job_id)
);

-- ─── TABLA: errores ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS errores (
    id_error    INT          NOT NULL AUTO_INCREMENT,
    job_id      INT          NOT NULL,
    id_usuario  INT          NOT NULL,
    fecha       DATE         NOT NULL,
    descripcion VARCHAR(500) NOT NULL,
    PRIMARY KEY (id_error),
    FOREIGN KEY (job_id)     REFERENCES trabajos(job_id),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

-- ─── SEED DATA ─────────────────────────────────────────────────────────────────

-- Usuario seed
INSERT INTO usuarios (nombre, email, rol)
VALUES ('Ana Lopez', 'ana@empresa.com', 'analista')
ON DUPLICATE KEY UPDATE nombre = nombre;

-- Trabajo seed
INSERT INTO trabajos (id_usuario, nombre_archivo, estado, fecha_carga, csv_s3_key)
VALUES (
    1,
    'ventas_abril_2026.csv',
    'COMPLETADO',
    '2026-04-01',
    'uploads/ventas_abril_2026.csv'
)
ON DUPLICATE KEY UPDATE estado = estado;

-- Reporte seed
INSERT INTO reportes (job_id, periodo, pdf_s3_key, fecha_generado)
VALUES (
    1,
    'Abril 2026',
    'reports/reporte_abril_2026.pdf',
    '2026-04-01'
)
ON DUPLICATE KEY UPDATE periodo = periodo;