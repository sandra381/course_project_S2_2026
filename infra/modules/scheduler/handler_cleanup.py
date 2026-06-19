import json
import os
import boto3
import pymysql
from datetime import datetime, timedelta

# ─── CONFIGURACION ─────────────────────────────────────────────────────────────
DB_HOST     = os.environ["DB_HOST"].split(":")[0]
DB_NAME     = os.environ["DB_NAME"]
DB_USER     = os.environ["DB_USER"]


# Jobs que lleven más de estas horas en PENDIENTE o PROCESANDO se marcan FALLIDO
STALE_HOURS = int(os.environ.get("STALE_HOURS", "2"))

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


def handler(event, context):
    """
    Lambda de limpieza — ejecutada por EventBridge Scheduler cada hora.
    Marca como FALLIDO cualquier job que lleve más de STALE_HOURS horas
    en estado PENDIENTE o PROCESANDO, lo que indica que el procesamiento
    se colgó o Lambda Worker falló sin actualizar el estado en RDS.
    """
    print(f"[cleanup] Iniciando limpieza — {datetime.utcnow().isoformat()}")

    cutoff = datetime.utcnow() - timedelta(hours=STALE_HOURS)
    updated = 0

    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # Buscar jobs estancados
            cursor.execute("""
                SELECT job_id, estado, fecha_carga
                FROM trabajos
                WHERE estado IN ('PENDIENTE', 'PROCESANDO')
                AND fecha_carga < %s
            """, (cutoff.date(),))
            stale_jobs = cursor.fetchall()

            for job in stale_jobs:
                # Marcar como FALLIDO
                cursor.execute("""
                    UPDATE trabajos SET estado = 'FALLIDO'
                    WHERE job_id = %s
                """, (job["job_id"],))

                # Registrar en tabla errores
                cursor.execute("""
                    INSERT INTO errores (job_id, id_usuario, fecha, descripcion)
                    SELECT job_id, id_usuario, %s,CONCAT('Job marcado FALLIDO por limpieza automatica tras ',%s, ' horas en estado ', estado)
                    FROM trabajos WHERE job_id = %s
                """, (datetime.utcnow().date(), STALE_HOURS, job["job_id"]))

                updated += 1
                print(f"[cleanup] Job {job['job_id']} marcado como FALLIDO")

        conn.commit()
        conn.close()

    except Exception as e:
        print(f"[cleanup] ERROR: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }

    print(f"[cleanup] Finalizado — {updated} jobs marcados como FALLIDO")
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": f"Limpieza completada",
            "jobs_marcados_fallido": updated
        })
    }
