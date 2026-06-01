import json
import os

# ─── CONFIGURACION ─────────────────────────────────────────────────────────────
ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")
PROJECT     = os.environ.get("PROJECT", "oyd-project")


def handler(event, context):
    """
    Lambda Worker — procesa archivos CSV y genera reportes PDF.
    Implementacion completa en D4 cuando se integre SQS.
    Por ahora retorna un mensaje de confirmacion.
    """
    print(f"[{PROJECT}] Worker invocado en ambiente {ENVIRONMENT}")
    print(f"Evento recibido: {json.dumps(event)}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "status": "ok",
            "message": "Worker placeholder — implementacion completa en D4"
        })
    }