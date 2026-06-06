import json
import os
import boto3
import pymysql
from datetime import datetime, date

# ─── CONFIGURACION ─────────────────────────────────────────────────────────────
# RDS devuelve el endpoint con puerto (host:3306), se extrae solo el host
DB_HOST     = os.environ["DB_HOST"].split(":")[0]
DB_NAME     = os.environ["DB_NAME"]
DB_USER     = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]
S3_BUCKET   = os.environ["S3_BUCKET_NAME"]

s3 = boto3.client("s3")

HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


# ─── HELPERS ───────────────────────────────────────────────────────────────────

def get_db_connection():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5,
    )


def serialize(row):
    """Convierte fechas y tipos no serializables a string para json.dumps."""
    for key, value in row.items():
        if isinstance(value, (datetime, date)):
            row[key] = value.isoformat()
    return row


def ok(body, status=200):
    return {"statusCode": status, "headers": HEADERS, "body": json.dumps(body)}


def err(message, status=500):
    return {"statusCode": status, "headers": HEADERS, "body": json.dumps({"error": message})}


# ─── HANDLER PRINCIPAL ─────────────────────────────────────────────────────────

def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path   = event.get("rawPath", "/")

    print(f"[SPVR] {method} {path}")

    # ── GET /  →  health check ─────────────────────────────────────────────────
    if method == "GET" and path == "/":
        return ok({"status": "ok", "service": "spvr-api"})

    # ── POST /setup  →  crea tablas + seed data ────────────────────────────────
    # Úsalo UNA vez después del primer terraform apply para inicializar la BD.
    elif method == "POST" and path == "/setup":
        return handle_setup()

    # ── POST /login  →  busca usuario por email, devuelve { user, token } ──────
    # El frontend envía { email, password }.
    # Por ahora no hay campo password en la BD, así que solo validamos el email.
    # Suficiente para probar todas las pantallas en modo live.
    elif method == "POST" and path == "/login":
        body = json.loads(event.get("body") or "{}")
        return handle_login(body)

    # ── GET /jobs  →  lista trabajos (Dashboard) ───────────────────────────────
    elif method == "GET" and path == "/jobs":
        return handle_get_jobs()

    # ── GET /jobs/{id}  →  detalle de un trabajo (JobStatus polling) ───────────
    elif method == "GET" and path.startswith("/jobs/"):
        job_id = path.split("/jobs/")[1]
        return handle_get_job(job_id)

    # ── POST /upload  →  genera presigned URL + crea registro en trabajos ──────
    # El frontend espera: { job_id, upload_url, s3_key }
    elif method == "POST" and path == "/upload":
        body = json.loads(event.get("body") or "{}")
        return handle_upload(body)

    # ── GET /reports  →  historial de reportes (History) ──────────────────────
    elif method == "GET" and path == "/reports":
        return handle_get_reports()

    # ── GET /reports/{id}/download  →  presigned URL para descargar PDF ────────
    elif method == "GET" and path.startswith("/reports/") and path.endswith("/download"):
        report_id = path.split("/reports/")[1].replace("/download", "")
        return handle_report_download(report_id)

    # ── GET /errors  →  registro de errores (ErrorLog, AdminDashboard) ─────────
    elif method == "GET" and path == "/errors":
        return handle_get_errors()

    # ── 404 ────────────────────────────────────────────────────────────────────
    else:
        return err(f"Ruta no encontrada: {method} {path}", 404)


# ─── SETUP ─────────────────────────────────────────────────────────────────────

def handle_setup():
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:

            cur.execute("""
                CREATE TABLE IF NOT EXISTS usuarios (
                    id_usuario INT          NOT NULL AUTO_INCREMENT,
                    nombre     VARCHAR(100) NOT NULL,
                    email      VARCHAR(100) NOT NULL UNIQUE,
                    rol        VARCHAR(50)  NOT NULL,
                    PRIMARY KEY (id_usuario)
                )
            """)

            cur.execute("""
                CREATE TABLE IF NOT EXISTS trabajos (
                    job_id         INT          NOT NULL AUTO_INCREMENT,
                    id_usuario     INT          NOT NULL,
                    nombre_archivo VARCHAR(255) NOT NULL,
                    estado         VARCHAR(50)  NOT NULL,
                    fecha_carga    DATE         NOT NULL,
                    csv_s3_key     VARCHAR(500) NOT NULL,
                    PRIMARY KEY (job_id),
                    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
                )
            """)

            cur.execute("""
                CREATE TABLE IF NOT EXISTS reportes (
                    id_reporte     INT          NOT NULL AUTO_INCREMENT,
                    job_id         INT          NOT NULL,
                    periodo        VARCHAR(50)  NOT NULL,
                    pdf_s3_key     VARCHAR(500) NOT NULL,
                    fecha_generado DATE         NOT NULL,
                    PRIMARY KEY (id_reporte),
                    FOREIGN KEY (job_id) REFERENCES trabajos(job_id)
                )
            """)

            cur.execute("""
                CREATE TABLE IF NOT EXISTS errores (
                    id_error    INT          NOT NULL AUTO_INCREMENT,
                    job_id      INT          NOT NULL,
                    id_usuario  INT          NOT NULL,
                    fecha       DATE         NOT NULL,
                    descripcion VARCHAR(500) NOT NULL,
                    PRIMARY KEY (id_error),
                    FOREIGN KEY (job_id)    REFERENCES trabajos(job_id),
                    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
                )
            """)

            # ── Seed: 5 usuarios (uno por rol) ─────────────────────────────────
            usuarios_seed = [
                ("Ana Lopez",       "ana@spvr.com",    "analista"),
                ("Carlos Perez",    "carlos@spvr.com", "gerente"),
                ("Juan Perez",      "juan@spvr.com",   "vendedor"),
                ("Admin Principal", "admin@spvr.com",  "administrador"),
                ("Auditor 01",      "audit@spvr.com",  "auditor"),
            ]
            for nombre, email, rol in usuarios_seed:
                cur.execute("""
                    INSERT INTO usuarios (nombre, email, rol)
                    VALUES (%s, %s, %s)
                    ON DUPLICATE KEY UPDATE nombre = nombre
                """, (nombre, email, rol))

            # ── Seed: trabajos de ejemplo ───────────────────────────────────────
            trabajos_seed = [
                (1, "ventas_mayo_2026.csv",      "PROCESANDO", "2026-05-24", "uploads/ventas_mayo_2026.csv"),
                (1, "reporte_anual_2025_v2.csv", "COMPLETADO", "2026-05-23", "uploads/reporte_anual_2025_v2.csv"),
                (1, "ventas_noreste_final.csv",  "COMPLETADO", "2026-05-22", "uploads/ventas_noreste_final.csv"),
                (1, "error_carga_datos.csv",     "FALLIDO",    "2026-05-22", "uploads/error_carga_datos.csv"),
            ]
            for t in trabajos_seed:
                cur.execute("""
                    INSERT INTO trabajos (id_usuario, nombre_archivo, estado, fecha_carga, csv_s3_key)
                    VALUES (%s, %s, %s, %s, %s)
                """, t)

            # ── Seed: un reporte para el job_id 2 (COMPLETADO) ─────────────────
            cur.execute("""
                INSERT INTO reportes (job_id, periodo, pdf_s3_key, fecha_generado)
                VALUES (2, '2025-12', 'reports/reporte_anual_2025_v2.pdf', '2026-05-23')
            """)

            # ── Seed: errores de ejemplo ────────────────────────────────────────
            errores_seed = [
                (4, 1, "2026-05-22", "Error de validación en columna customer_id. Tipo de dato no coincide con el esquema CSV."),
                (3, 1, "2026-05-22", "Columnas faltantes en el archivo: unit_price, city."),
            ]
            for e in errores_seed:
                cur.execute("""
                    INSERT INTO errores (job_id, id_usuario, fecha, descripcion)
                    VALUES (%s, %s, %s, %s)
                """, e)

        conn.commit()
        conn.close()
        return ok({"message": "Tablas creadas y seed data insertado correctamente."})

    except Exception as e:
        return err(str(e))


# ─── LOGIN ─────────────────────────────────────────────────────────────────────
# Busca el usuario por email en la tabla usuarios.
# No hay campo password todavía — suficiente para probar el flujo live.
# El frontend guarda el objeto user en localStorage y lo usa en todas las páginas.

def handle_login(body):
    email = body.get("email", "").strip().lower()
    if not email:
        return err("El campo email es requerido.", 400)

    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id_usuario, nombre, email, rol FROM usuarios WHERE LOWER(email) = %s",
                (email,)
            )
            user = cur.fetchone()
        conn.close()

        if not user:
            return err("Usuario no encontrado. Verifica tu correo.", 401)

        # Token simulado — suficiente para probar el frontend
        token = f"spvr-token-{user['id_usuario']}"

        return ok({
            "user": {
                "id":     user["id_usuario"],
                "nombre": user["nombre"],
                "email":  user["email"],
                "rol":    user["rol"],
            },
            "token": token,
        })

    except Exception as e:
        return err(str(e))


# ─── GET /jobs ─────────────────────────────────────────────────────────────────
# Devuelve los últimos 20 trabajos.
# El Dashboard muestra esta lista con estado y nombre de archivo.

def handle_get_jobs():
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT t.job_id, t.nombre_archivo, t.estado, t.fecha_carga,t.csv_s3_key, u.nombre AS usuario
                FROM trabajos t
                JOIN usuarios u ON t.id_usuario = u.id_usuario
                ORDER BY t.job_id DESC
                LIMIT 20
            """)
            rows = [serialize(r) for r in cur.fetchall()]
        conn.close()
        return ok({"jobs": rows})

    except Exception as e:
        return err(str(e))


# ─── GET /jobs/{id} ────────────────────────────────────────────────────────────
# Devuelve el detalle de un trabajo por su job_id.
# JobStatus hace polling a esta ruta cada 3 segundos.

def handle_get_job(job_id):
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT t.job_id, t.nombre_archivo, t.estado, t.fecha_carga,t.csv_s3_key, u.nombre AS usuario
                FROM trabajos t
                JOIN usuarios u ON t.id_usuario = u.id_usuario
                WHERE t.job_id = %s
            """, (job_id,))
            row = cur.fetchone()
        conn.close()

        if not row:
            return err("Trabajo no encontrado.", 404)

        return ok(serialize(row))

    except Exception as e:
        return err(str(e))


# ─── POST /upload ───────────────────────────────────────────────────────────────
# 1. Crea un registro en la tabla trabajos con estado PENDIENTE.
# 2. Genera una presigned URL para que el frontend suba el CSV directo a S3.
# El frontend envía: { filename, id_usuario }
# El frontend espera recibir: { job_id, upload_url, s3_key }

def handle_upload(body):
    filename   = body.get("filename", "archivo.csv")
    id_usuario = body.get("id_usuario", 1)
    timestamp  = datetime.utcnow().strftime("%Y%m%d%H%M%S")
    s3_key     = f"uploads/{timestamp}_{filename}"

    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO trabajos (id_usuario, nombre_archivo, estado, fecha_carga, csv_s3_key)
                VALUES (%s, %s, 'PENDIENTE', %s, %s)
            """, (id_usuario, filename, date.today().isoformat(), s3_key))
            job_id = cur.lastrowid
        conn.commit()
        conn.close()

        # Presigned URL válida por 5 minutos para subir el CSV directo a S3
        upload_url = s3.generate_presigned_url(
            "put_object",
            Params={"Bucket": S3_BUCKET, "Key": s3_key, "ContentType": "text/csv"},
            ExpiresIn=300,
        )

        return ok({"job_id": job_id, "upload_url": upload_url, "s3_key": s3_key}, 201)

    except Exception as e:
        return err(str(e))


# ─── GET /reports ───────────────────────────────────────────────────────────────
# Devuelve el historial de reportes con el nombre de archivo del trabajo asociado.
# History.jsx espera: { reports: [...] } donde cada reporte tiene nombre_archivo y usuario.

def handle_get_reports():
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT r.id_reporte, r.job_id, r.periodo, r.pdf_s3_key, r.fecha_generado,t.nombre_archivo, t.estado, u.nombre AS usuario
                FROM reportes r
                JOIN trabajos t ON r.job_id = t.job_id
                JOIN usuarios u ON t.id_usuario = u.id_usuario
                ORDER BY r.id_reporte DESC
                LIMIT 50
            """)
            rows = [serialize(r) for r in cur.fetchall()]
        conn.close()
        return ok({"reports": rows})

    except Exception as e:
        return err(str(e))


# ─── GET /reports/{id}/download ────────────────────────────────────────────────
# Genera una presigned URL para descargar el PDF del reporte desde S3.
# History.jsx llama a esta ruta cuando el usuario hace clic en "Descargar".

def handle_report_download(report_id):
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute(
                "SELECT pdf_s3_key FROM reportes WHERE id_reporte = %s",
                (report_id,)
            )
            row = cur.fetchone()
        conn.close()

        if not row:
            return err("Reporte no encontrado.", 404)

        download_url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": row["pdf_s3_key"]},
            ExpiresIn=300,
        )

        return ok({"download_url": download_url})

    except Exception as e:
        return err(str(e))


# ─── GET /errors ────────────────────────────────────────────────────────────────
# Devuelve el registro de errores con nombre de usuario.
# ErrorLog.jsx espera: { errors: [...] } donde cada error tiene id, job_id, usuario, rol, fecha, descripcion.

def handle_get_errors():
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT e.id_error AS id, e.job_id, e.fecha, e.descripcion,u.nombre AS usuario, u.rol
                FROM errores e
                JOIN usuarios u ON e.id_usuario = u.id_usuario
                ORDER BY e.id_error DESC
                LIMIT 50
            """)
            rows = [serialize(r) for r in cur.fetchall()]
        conn.close()
        return ok({"errors": rows})

    except Exception as e:
        return err(str(e))