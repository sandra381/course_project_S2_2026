import json
import os
import boto3
import pymysql
from datetime import datetime

# ─── CONFIGURACION ─────────────────────────────────────────────────────────────
DB_HOST           = os.environ["DB_HOST"].split(":")[0]
DB_NAME           = os.environ["DB_NAME"]
DB_USER           = os.environ["DB_USER"]
DB_PASSWORD       = os.environ["DB_PASSWORD"]
S3_BUCKET         = os.environ["S3_BUCKET_NAME"]
S3_REPORTS_BUCKET = os.environ["S3_REPORTS_BUCKET"]
SQS_QUEUE_URL     = os.environ["SQS_QUEUE_URL"]

s3  = boto3.client("s3")
sqs = boto3.client("sqs")


def get_db_connection():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5
    )


def serialize_row(row):
    for key, value in row.items():
        if hasattr(value, "isoformat"):
            row[key] = value.isoformat()
    return row


def ok(body):
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }


def error(status, message):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"error": message})
    }


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path   = event.get("rawPath", "/")

    # ─── GET / — health check ──────────────────────────────────────────────────
    if method == "GET" and path == "/":
        return ok({"status": "ok", "service": "spvr-api"})

    # ─── POST /setup — crea tablas y seed data ─────────────────────────────────
    elif method == "POST" and "/setup" in path:
        try:
            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS usuarios (
                        id_usuario INT NOT NULL AUTO_INCREMENT,
                        nombre VARCHAR(100) NOT NULL,
                        email VARCHAR(100) NOT NULL UNIQUE,
                        rol VARCHAR(50) NOT NULL,
                        PRIMARY KEY (id_usuario)
                    )
                """)
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS trabajos (
                        job_id INT NOT NULL AUTO_INCREMENT,
                        id_usuario INT NOT NULL,
                        nombre_archivo VARCHAR(255) NOT NULL,
                        estado VARCHAR(50) NOT NULL,
                        fecha_carga DATE NOT NULL,
                        csv_s3_key VARCHAR(500) NOT NULL,
                        PRIMARY KEY (job_id),
                        FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
                    )
                """)
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS reportes (
                        id_reporte INT NOT NULL AUTO_INCREMENT,
                        job_id INT NOT NULL,
                        periodo VARCHAR(50) NOT NULL,
                        pdf_s3_key VARCHAR(500) NOT NULL,
                        fecha_generado DATE NOT NULL,
                        PRIMARY KEY (id_reporte),
                        FOREIGN KEY (job_id) REFERENCES trabajos(job_id)
                    )
                """)
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS errores (
                        id_error INT NOT NULL AUTO_INCREMENT,
                        job_id INT NOT NULL,
                        id_usuario INT NOT NULL,
                        fecha DATE NOT NULL,
                        descripcion VARCHAR(500) NOT NULL,
                        PRIMARY KEY (id_error),
                        FOREIGN KEY (job_id) REFERENCES trabajos(job_id),
                        FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
                    )
                """)
                cursor.execute("""
                    INSERT INTO usuarios (nombre, email, rol)
                    VALUES ('Ana Lopez', 'ana@empresa.com', 'analista')
                    ON DUPLICATE KEY UPDATE nombre = nombre
                """)
                cursor.execute("""
                    INSERT INTO trabajos (id_usuario, nombre_archivo, estado, fecha_carga, csv_s3_key)
                    VALUES (1, 'ventas_abril_2026.csv', 'COMPLETADO', '2026-04-01', 'uploads/ventas_abril_2026.csv')
                """)
            conn.commit()
            conn.close()
            return ok({"message": "tablas y seed data creados correctamente"})
        except Exception as e:
            return error(500, str(e))

    # ─── GET /jobs — lista trabajos del usuario ────────────────────────────────
    elif method == "GET" and path == "/jobs":
        try:
            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute("SELECT * FROM trabajos ORDER BY fecha_carga DESC LIMIT 20")
                rows = [serialize_row(r) for r in cursor.fetchall()]
            conn.close()
            return ok({"jobs": rows})
        except Exception as e:
            return error(500, str(e))

    # ─── POST /upload — genera presigned URL para subir CSV a S3 ──────────────
    # El frontend sube el CSV directo a S3 con esa URL, sin pasar por Lambda.
    elif method == "POST" and "/upload" in path:
        try:
            body       = json.loads(event.get("body", "{}"))
            filename   = body.get("filename", "archivo.csv")
            id_usuario = body.get("id_usuario", 1)

            timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S")
            s3_key    = f"uploads/{timestamp}_{filename}"

            # Crear registro en RDS con estado PENDIENTE
            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO trabajos (id_usuario, nombre_archivo, estado, fecha_carga, csv_s3_key)
                    VALUES (%s, %s, 'PENDIENTE', %s, %s)
                    """,
                    (id_usuario, filename, datetime.utcnow().date(), s3_key)
                )
                job_id = cursor.lastrowid
            conn.commit()
            conn.close()

            # Generar presigned URL para que el frontend suba directo a S3
            upload_url = s3.generate_presigned_url(
                "put_object",
                Params={
                    "Bucket": S3_BUCKET,
                    "Key": s3_key,
                    "ContentType": "text/csv"
                },
                ExpiresIn=300
            )

            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "job_id": job_id,
                    "upload_url": upload_url,
                    "s3_key": s3_key,
                    "status": "PENDIENTE"
                })
            }
        except Exception as e:
            return error(500, str(e))

    # ─── POST /jobs/enqueue — mete mensaje en SQS ─────────────────────────────
    # Requerido por Deliverable E. Recibe job_id y publica en SQS.
    # Devuelve HTTP 202 con el message_id real de SQS.
    elif method == "POST" and "/jobs/enqueue" in path:
        try:
            body       = json.loads(event.get("body", "{}"))
            job_id     = body.get("job_id")
            id_usuario = body.get("id_usuario", 1)

            if not job_id:
                return error(400, "job_id es requerido")

            # Obtener csv_s3_key y nombre_archivo desde RDS
            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT csv_s3_key, nombre_archivo FROM trabajos WHERE job_id = %s",
                    (job_id,)
                )
                row = cursor.fetchone()
            conn.close()

            if not row:
                return error(404, f"job_id {job_id} no encontrado")

            # Publicar mensaje en SQS
            mensaje = {
                "job_id": job_id,
                "csv_s3_key": row["csv_s3_key"],
                "nombre_archivo": row["nombre_archivo"],
                "id_usuario": id_usuario
            }

            response = sqs.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=json.dumps(mensaje)
            )

            print(f"[api] Mensaje encolado job_id={job_id} message_id={response['MessageId']}")

            return {
                "statusCode": 202,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "message_id": response["MessageId"],
                    "job_id": job_id,
                    "status": "enqueued"
                })
            }
        except Exception as e:
            return error(500, str(e))

    # ─── GET /reports — historial de reportes ─────────────────────────────────
    elif method == "GET" and path == "/reports":
        try:
            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT r.id_reporte, r.job_id, r.periodo, r.pdf_s3_key,
                           r.fecha_generado, t.nombre_archivo, t.id_usuario
                    FROM reportes r
                    JOIN trabajos t ON r.job_id = t.job_id
                    ORDER BY r.fecha_generado DESC
                    LIMIT 20
                """)
                rows = [serialize_row(r) for r in cursor.fetchall()]
            conn.close()
            return ok({"reports": rows})
        except Exception as e:
            return error(500, str(e))

    # ─── GET /reports/{id}/download — presigned URL del PDF ───────────────────
    elif method == "GET" and "/reports/" in path and "/download" in path:
        try:
            parts    = path.strip("/").split("/")
            reporte_id = parts[1]

            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT pdf_s3_key FROM reportes WHERE id_reporte = %s",
                    (reporte_id,)
                )
                row = cursor.fetchone()
            conn.close()

            if not row:
                return error(404, "Reporte no encontrado")

            download_url = s3.generate_presigned_url(
                "get_object",
                Params={
                    "Bucket": S3_REPORTS_BUCKET,
                    "Key": row["pdf_s3_key"]
                },
                ExpiresIn=300
            )

            return ok({"download_url": download_url})
        except Exception as e:
            return error(500, str(e))

    # ─── GET /reports/{id}/metrics — JSON de métricas para el frontend ────────
    elif method == "GET" and "/reports/" in path and "/metrics" in path:
        try:
            parts      = path.strip("/").split("/")
            reporte_id = parts[1]

            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT job_id, pdf_s3_key FROM reportes WHERE id_reporte = %s",
                    (reporte_id,)
                )
                row = cursor.fetchone()
            conn.close()

            if not row:
                return error(404, "Reporte no encontrado")

            # El JSON de métricas tiene el mismo job_id que el PDF
            json_key = f"reports/metricas_{row['job_id']}.json"
            obj      = s3.get_object(Bucket=S3_REPORTS_BUCKET, Key=json_key)
            metricas = json.loads(obj["Body"].read())

            return ok(metricas)
        except Exception as e:
            return error(500, str(e))

    # ─── GET /errors — registro de errores (admin) ────────────────────────────
    elif method == "GET" and "/errors" in path:
        try:
            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT e.id_error, e.job_id, e.id_usuario,
                           e.fecha, e.descripcion, u.nombre, u.email
                    FROM errores e
                    JOIN usuarios u ON e.id_usuario = u.id_usuario
                    ORDER BY e.fecha DESC
                    LIMIT 50
                """)
                rows = [serialize_row(r) for r in cursor.fetchall()]
            conn.close()
            return ok({"errors": rows})
        except Exception as e:
            return error(500, str(e))

    # ─── POST /jobs (legacy — mantener compatibilidad con D3) ─────────────────
    elif method == "POST" and path == "/jobs":
        try:
            body      = json.loads(event.get("body", "{}"))
            timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S")
            object_key = f"uploads/{timestamp}.json"

            s3.put_object(
                Bucket=S3_BUCKET,
                Key=object_key,
                Body=json.dumps(body),
                ContentType="application/json"
            )

            return {
                "statusCode": 201,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"object_key": object_key})
            }
        except Exception as e:
            return error(500, str(e))

    # ─── 404 ───────────────────────────────────────────────────────────────────
    else:
        return error(404, "route not found")
