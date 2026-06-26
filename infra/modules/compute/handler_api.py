import json
import os
from botocore.client import Config
import boto3
import pymysql
from datetime import datetime
from botocore.client import Config
import bcrypt
import jwt
from datetime import timedelta
from decimal import Decimal

# ─── CONFIGURACION ─────────────────────────────────────────────────────────────
DB_HOST           = os.environ["DB_HOST"].split(":")[0]
DB_NAME           = os.environ["DB_NAME"]
DB_USER           = os.environ["DB_USER"]
S3_BUCKET         = os.environ["S3_BUCKET_NAME"]
S3_REPORTS_BUCKET = os.environ["S3_REPORTS_BUCKET"]
SQS_QUEUE_URL     = os.environ["SQS_QUEUE_URL"]
JWT_SECRET = os.environ["JWT_SECRET"]

s3 = boto3.client("s3", config=Config(signature_version="s3v4"))
sqs = boto3.client("sqs")

_sm = boto3.client("secretsmanager")
DB_PASSWORD = _sm.get_secret_value(
    SecretId=os.environ["DB_SECRET_ARN"]
)["SecretString"]

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
        elif isinstance(value, Decimal):
            row[key] = float(value)
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
    elif method == "POST" and path == "/login":
        try:
            body     = json.loads(event.get("body", "{}"))
            email    = body.get("email", "").strip()
            password = body.get("password", "")

            if not email or not password:
                return error(400, "email y password son requeridos")

            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT id_usuario, nombre, email, rol, password_hash FROM usuarios WHERE email = %s",
                    (email,)
                )
                usuario = cursor.fetchone()
            conn.close()

            if not usuario:
                return error(401, "Correo o contraseña incorrectos.")

            # Validación real de contraseña con bcrypt
            if not usuario["password_hash"]:
                return error(401, "Este usuario no tiene contraseña configurada.")

            password_valida = bcrypt.checkpw(
                password.encode("utf-8"),
                usuario["password_hash"].encode("utf-8")
            )
            if not password_valida:
                return error(401, "Correo o contraseña incorrectos.")

            # Generar JWT real, expira en 8 horas
            payload = {
                "id_usuario": usuario["id_usuario"],
                "email": usuario["email"],
                "rol": usuario["rol"],
                "exp": datetime.utcnow() + timedelta(hours=8)
            }
            token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")

            return ok({
                "token": token,
                "user": {
                    "id_usuario": usuario["id_usuario"],
                    "nombre": usuario["nombre"],
                    "email": usuario["email"],
                    "rol": usuario["rol"]
                }
            })
        except Exception as e:
            return error(500, str(e))

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
                try:
                    cursor.execute("""
                        ALTER TABLE usuarios
                        ADD COLUMN password_hash VARCHAR(255) NULL
                    """)
                except Exception as alter_err:
                    if "1060" not in str(alter_err):
                        raise
                try:
                    cursor.execute("""
                        ALTER TABLE errores
                        MODIFY COLUMN fecha DATETIME NOT NULL
                    """)
                except Exception as alter_err:
                    print(f"[setup] No se pudo alterar columna fecha de errores: {str(alter_err)}")
                try:
                    cursor.execute("""
                        ALTER TABLE trabajos
                        MODIFY COLUMN fecha_carga DATETIME NOT NULL
                    """)
                except Exception as alter_err:
                    print(f"[setup] No se pudo alterar columna fecha_carga: {str(alter_err)}")
                try:
                    cursor.execute("""
                        ALTER TABLE reportes
                        MODIFY COLUMN fecha_generado DATETIME NOT NULL
                    """)
                except Exception as alter_err:
                    print(f"[setup] No se pudo alterar columna fecha_generado: {str(alter_err)}")            
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS trabajos (
                        job_id INT NOT NULL AUTO_INCREMENT,
                        id_usuario INT NOT NULL,
                        nombre_archivo VARCHAR(255) NOT NULL,
                        estado VARCHAR(50) NOT NULL,
                        fecha_carga DATETIME NOT NULL,
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
                        fecha_generado DATETIME NOT NULL,
                        PRIMARY KEY (id_reporte),
                        FOREIGN KEY (job_id) REFERENCES trabajos(job_id)
                    )
                """)
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS errores (
                        id_error INT NOT NULL AUTO_INCREMENT,
                        job_id INT NOT NULL,
                        id_usuario INT NOT NULL,
                        fecha DATETIME NOT NULL,
                        descripcion VARCHAR(500) NOT NULL,
                        PRIMARY KEY (id_error),
                        FOREIGN KEY (job_id) REFERENCES trabajos(job_id),
                        FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
                    )
                """)
                # ── NUEVO: tabla de reportes individuales por vendedor ──────────
                # Cada fila = el desempeño de UN vendedor en UN CSV/período
                # específico, generado por el Worker al procesar ese CSV.
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS reportes_vendedor (
                        id_reporte_vendedor INT NOT NULL AUTO_INCREMENT,
                        job_id INT NOT NULL,
                        nombre_vendedor VARCHAR(100) NOT NULL,
                        periodo VARCHAR(50) NOT NULL,
                        total_vendido DECIMAL(12,2) NOT NULL,
                        productos_vendidos INT NOT NULL,
                        clientes_atendidos INT NOT NULL,
                        json_s3_key VARCHAR(500) NOT NULL,
                        fecha_generado DATETIME NOT NULL,
                        PRIMARY KEY (id_reporte_vendedor),
                        FOREIGN KEY (job_id) REFERENCES trabajos(job_id)
                    )
                """)
                # Insertar usuario admin con contraseña hasheada
                usuarios_seed = [
                    ("Ana Lopez",            "sandra.soria+ana@galileo.edu",          "analista",      "Ana2026!"),
                    ("Maria Julia",          "sandra.soria+mariajulia@galileo.edu",    "analista",      "Maria2026!"),
                    ("Pablo Juarez",         "sandra.soria+pablo.juarez@galileo.edu",  "analista",      "Pablo2026!"),
                    ("Miguel Paz",           "miguelpaz@spvr.com",                     "vendedor",      "Miguel2026!"),
                    ("Javier Hernandez",     "javier.hernandez@spvr.com",               "vendedor",      "Javier2026!"),
                    ("Consuelo Paiz",        "consuelo.paiz@spvr.com",                  "vendedor",      "Consuelo2026!"),
                    ("Andrea Gomez",         "andrea.gomez@spvr.com",                   "gerente",       "Andrea2026!"),
                    ("Santiago Lopez",       "santiago.lopez@spvr.com",                 "administrador", "Santiago2026!"),
                    ("Valentina Rodriguez",  "valentina.rodriguez@spvr.com",            "auditor",       "Valentina2026!"),
                ]

                for nombre, email, rol, password in usuarios_seed:
                    password_hash = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
                    cursor.execute("""
                        INSERT INTO usuarios (nombre, email, rol, password_hash)
                        VALUES (%s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash), rol = VALUES(rol)
                    """, (nombre, email, rol, password_hash))
            conn.commit()
            conn.close()
            return ok({"message": "tablas y seed data creados correctamente"})
        except Exception as e:
            return error(500, str(e))

    elif method == "POST" and path == "/admin/reset":
        try:
            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute("DELETE FROM reportes_vendedor")
                cursor.execute("DELETE FROM errores")
                cursor.execute("DELETE FROM reportes")
                cursor.execute("DELETE FROM trabajos")
                cursor.execute("DELETE FROM usuarios")
                cursor.execute("ALTER TABLE usuarios AUTO_INCREMENT = 1")
                cursor.execute("ALTER TABLE trabajos AUTO_INCREMENT = 1")
                cursor.execute("ALTER TABLE reportes AUTO_INCREMENT = 1")
                cursor.execute("ALTER TABLE errores AUTO_INCREMENT = 1")
                cursor.execute("ALTER TABLE reportes_vendedor AUTO_INCREMENT = 1")
            conn.commit()
            conn.close()
            return ok({"message": "Tablas vaciadas correctamente"})
        except Exception as e:
            return error(500, str(e))


    # ─── GET /jobs — lista trabajos del usuario ────────────────────────────────
    elif method == "GET" and path == "/jobs":
        try:
            query_params = event.get("queryStringParameters") or {}
            id_usuario   = query_params.get("id_usuario")
            limit        = int(query_params.get("limit", 20))
            offset       = int(query_params.get("offset", 0))

            conn = get_db_connection()
            with conn.cursor() as cursor:
                if id_usuario:
                    cursor.execute(
                        f"SELECT * FROM trabajos WHERE id_usuario = %s ORDER BY fecha_carga DESC LIMIT {limit} OFFSET {offset}",
                        (id_usuario,)
                        
                    )
                else:
                    cursor.execute(
                        f"SELECT * FROM trabajos ORDER BY fecha_carga DESC LIMIT {limit} OFFSET {offset}"
                    )
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
                    (id_usuario, filename, datetime.utcnow(), s3_key)
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
        
    elif method == "GET" and path.startswith("/jobs/") and path != "/jobs/enqueue":
        try:
            job_id = path.strip("/").split("/")[1]

            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT * FROM trabajos WHERE job_id = %s",
                    (job_id,)
                )
                row = cursor.fetchone()
            conn.close()

            if not row:
                return error(404, "Job no encontrado")

            return ok(serialize_row(row))
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
            query_params = event.get("queryStringParameters") or {}
            id_usuario   = query_params.get("id_usuario")

            conn = get_db_connection()
            with conn.cursor() as cursor:
                if id_usuario:
                    cursor.execute("""
                        SELECT r.id_reporte, r.job_id, r.periodo, r.pdf_s3_key,
                            r.fecha_generado, t.nombre_archivo, t.id_usuario,
                            t.csv_s3_key, u.nombre AS usuario
                        FROM reportes r
                        JOIN trabajos t ON r.job_id = t.job_id
                        JOIN usuarios u ON t.id_usuario = u.id_usuario
                        WHERE t.id_usuario = %s
                        ORDER BY r.fecha_generado DESC
                        LIMIT 20
                    """, (id_usuario,))
                else:
                    cursor.execute("""
                        SELECT r.id_reporte, r.job_id, r.periodo, r.pdf_s3_key,
                            r.fecha_generado, t.nombre_archivo, t.id_usuario,
                            t.csv_s3_key, u.nombre AS usuario
                        FROM reportes r
                        JOIN trabajos t ON r.job_id = t.job_id
                        JOIN usuarios u ON t.id_usuario = u.id_usuario
                        ORDER BY r.fecha_generado DESC
                        LIMIT 20
                    """)
                rows = [serialize_row(r) for r in cursor.fetchall()]
            conn.close()
            return ok({"reports": rows})
        except Exception as e:
            return error(500, str(e))
        
    elif method == "GET" and "/reports/" in path and "/csv" in path:
        try:
            parts      = path.strip("/").split("/")
            reporte_id = parts[1]

            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT t.csv_s3_key
                    FROM reportes r
                    JOIN trabajos t ON r.job_id = t.job_id
                    WHERE r.id_reporte = %s
                """, (reporte_id,))
                row = cursor.fetchone()
            conn.close()

            if not row:
                return error(404, "Reporte no encontrado")

            download_url = s3.generate_presigned_url(
                "get_object",
                Params={"Bucket": S3_BUCKET, "Key": row["csv_s3_key"]},
                ExpiresIn=300
            )

            return ok({"download_url": download_url})
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
        

    elif method == "GET" and path == "/seller/dashboard":
        try:
            query_params = event.get("queryStringParameters") or {}
            nombre = query_params.get("nombre")

            if not nombre:
                return error(400, "nombre del vendedor es requerido")

            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT total_vendido, productos_vendidos, clientes_atendidos,
                        json_s3_key, periodo, fecha_generado
                    FROM reportes_vendedor
                    WHERE nombre_vendedor = %s
                    ORDER BY fecha_generado DESC
                """, (nombre,))
                reportes = cursor.fetchall()
            conn.close()

            if not reportes:
                return ok({
                    "total_vendido": 0, "productos_vendidos": 0,
                    "clientes_atendidos": 0, "ranking_posicion": 0, "ranking_total": 0,
                    "top_productos": [], "evolucion_mensual": []
                })

            # Acumulado de todos los reportes históricos de este vendedor
            total_vendido       = float(sum(r["total_vendido"] for r in reportes))
            productos_vendidos  = int(sum(r["productos_vendidos"] for r in reportes))
            clientes_atendidos  = max(r["clientes_atendidos"] for r in reportes)

            # El más reciente trae el ranking más actualizado y el top de productos
            mas_reciente = reportes[0]
            obj = s3.get_object(Bucket=S3_REPORTS_BUCKET, Key=mas_reciente["json_s3_key"])
            datos_recientes = json.loads(obj["Body"].read())

            evolucion_mensual = [
                {
                    "mes": datetime.strptime(str(r["fecha_generado"])[:10], "%Y-%m-%d").strftime("%b"),
                    "total": float(r["total_vendido"])
                }
                for r in reversed(reportes)
            ]

            return ok({
                "total_vendido": total_vendido,
                "productos_vendidos": productos_vendidos,
                "clientes_atendidos": clientes_atendidos,
                "ranking_posicion": datos_recientes.get("ranking_posicion", 0),
                "ranking_total": datos_recientes.get("ranking_total", 0),
                "top_productos": datos_recientes.get("top_productos", []),
                "evolucion_mensual": evolucion_mensual
            })
        except Exception as e:
            return error(500, str(e))

    elif method == "GET" and path == "/seller/history":
        try:
            query_params = event.get("queryStringParameters") or {}
            nombre = query_params.get("nombre")

            if not nombre:
                return error(400, "nombre del vendedor es requerido")

            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT id_reporte_vendedor, job_id, periodo, total_vendido,
                        productos_vendidos, clientes_atendidos, fecha_generado
                    FROM reportes_vendedor
                    WHERE nombre_vendedor = %s
                    ORDER BY fecha_generado DESC
                    LIMIT 20
                """, (nombre,))
                rows = [serialize_row(r) for r in cursor.fetchall()]
            conn.close()
            return ok({"reportes": rows})
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
