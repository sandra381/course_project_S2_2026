import json
import os
import boto3
import pymysql
from datetime import datetime

# ─── CONFIGURACION ─────────────────────────────────────────────────────────────
DB_HOST = os.environ["DB_HOST"].split(":")[0]
DB_NAME     = os.environ["DB_NAME"]
DB_USER     = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]
S3_BUCKET   = os.environ["S3_BUCKET_NAME"]

s3 = boto3.client("s3")


def get_db_connection():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5
    )


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path   = event.get("rawPath", "/")

    # ─── GET / (health check) ──────────────────────────────────────────────────
    if method == "GET" and path == "/":
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"status": "ok", "service": "spvr-api"})
        }

    # ─── POST /setup (crea tablas y seed data) ─────────────────────────────────
    elif method == "POST" and "/setup" in path:
        try:
            conn = get_db_connection()
            with conn.cursor() as cursor:
                # Crear tablas
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
                # Seed data
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
            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"message": "tablas y seed data creados correctamente"})
            }
        except Exception as e:
            return {
                "statusCode": 500,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": str(e)})
            }

    # ─── GET /jobs ─────────────────────────────────────────────────────────────
    elif method == "GET" and "/jobs" in path:
        try:
            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute("SELECT * FROM trabajos LIMIT 10")
                rows = cursor.fetchall()
            conn.close()

            for row in rows:
                for key, value in row.items():
                    if hasattr(value, "isoformat"):
                        row[key] = value.isoformat()

            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"jobs": rows})
            }

        except Exception as e:
            return {
                "statusCode": 500,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": str(e)})
            }

    # ─── POST /jobs ────────────────────────────────────────────────────────────
    elif method == "POST" and "/jobs" in path:
        try:
            body = json.loads(event.get("body", "{}"))
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
            return {
                "statusCode": 500,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": str(e)})
            }

    # ─── 404 ───────────────────────────────────────────────────────────────────
    else:
        return {
            "statusCode": 404,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "route not found"})
        }