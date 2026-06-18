import json
import os
import io
import boto3
import pymysql
import pandas as pd
from datetime import datetime
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle

# ─── CONFIGURACION ─────────────────────────────────────────────────────────────
DB_HOST           = os.environ["DB_HOST"].split(":")[0]
DB_NAME           = os.environ["DB_NAME"]
DB_USER           = os.environ["DB_USER"]
S3_CSV_BUCKET     = os.environ["S3_BUCKET_NAME"]
S3_REPORTS_BUCKET = os.environ["S3_REPORTS_BUCKET"]
SQS_QUEUE_URL     = os.environ["SQS_QUEUE_URL"]

s3  = boto3.client("s3")
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


# ─── CALCULAR METRICAS DEL CSV ─────────────────────────────────────────────────
def calcular_metricas(df):
    total_vendido = float((df["quantity"] * df["unit_price"]).sum())

    # Top 5 productos
    top_productos = (
        df.groupby("product_name")
        .apply(lambda x: (x["quantity"] * x["unit_price"]).sum())
        .sort_values(ascending=False)
        .head(5)
    )
    producto_top = top_productos.index[0] if len(top_productos) > 0 else ""

    # Ventas por ciudad
    ventas_ciudad = (
        df.groupby("city")
        .apply(lambda x: (x["quantity"] * x["unit_price"]).sum())
        .sort_values(ascending=False)
    )
    ciudad_top = ventas_ciudad.index[0] if len(ventas_ciudad) > 0 else ""

    # Top 5 clientes
    top_clientes = (
        df.groupby(["customer_id", "customer_name"])
        .apply(lambda x: (x["quantity"] * x["unit_price"]).sum())
        .sort_values(ascending=False)
        .head(5)
        .reset_index()
    )

    # Evolucion mensual
    df["sale_date"] = pd.to_datetime(df["sale_date"])
    df["mes"] = df["sale_date"].dt.strftime("%b")
    df["mes_num"] = df["sale_date"].dt.month
    evolucion = (
        df.groupby(["mes_num", "mes"])
        .apply(lambda x: (x["quantity"] * x["unit_price"]).sum())
        .reset_index()
        .sort_values("mes_num")
    )

    return {
        "total_vendido": total_vendido,
        "producto_top": producto_top,
        "ciudad_top": ciudad_top,
        "total_registros": len(df),
        "clientes_frecuentes": df["customer_id"].nunique(),
        "ciudades_analizadas": df["city"].nunique(),
        "top_productos": [
            {"nombre": nombre, "total": float(total)}
            for nombre, total in top_productos.items()
        ],
        "ventas_ciudad": [
            {"ciudad": ciudad, "total": float(total)}
            for ciudad, total in ventas_ciudad.items()
        ],
        "clientes_top": [
            {
                "customer_id": str(row["customer_id"]),
                "nombre": row["customer_name"],
                "total": float(row[0])
            }
            for _, row in top_clientes.iterrows()
        ],
        "evolucion_mensual": [
            {"mes": row["mes"], "total": float(row[0])}
            for _, row in evolucion.iterrows()
        ]
    }


# ─── GENERAR PDF CON REPORTLAB ─────────────────────────────────────────────────
def generar_pdf(metricas, job_id, nombre_archivo, periodo):
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []

    # Titulo
    story.append(Paragraph(f"Reporte de Ventas — {nombre_archivo}", styles["Title"]))
    story.append(Paragraph(f"Período: {periodo} | Job ID: {job_id} | Generado: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}", styles["Normal"]))
    story.append(Spacer(1, 0.3 * inch))

    # KPIs
    story.append(Paragraph("Resumen General", styles["Heading2"]))
    kpis = [
        ["Total Vendido", f"Q{metricas['total_vendido']:,.0f}"],
        ["Producto más vendido", metricas["producto_top"]],
        ["Ciudad con más ventas", metricas["ciudad_top"]],
        ["Total registros", str(metricas["total_registros"])],
        ["Clientes únicos", str(metricas["clientes_frecuentes"])],
        ["Ciudades analizadas", str(metricas["ciudades_analizadas"])],
    ]
    t = Table(kpis, colWidths=[3 * inch, 3 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#f0f0f0")),
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("PADDING", (0, 0), (-1, -1), 6),
    ]))
    story.append(t)
    story.append(Spacer(1, 0.3 * inch))

    # Top productos
    story.append(Paragraph("Top Productos más Vendidos", styles["Heading2"]))
    prod_data = [["Producto", "Total (Q)"]] + [
        [p["nombre"], f"Q{p['total']:,.0f}"]
        for p in metricas["top_productos"]
    ]
    t2 = Table(prod_data, colWidths=[4 * inch, 2 * inch])
    t2.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e85d4a")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("PADDING", (0, 0), (-1, -1), 6),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#fafafa")]),
    ]))
    story.append(t2)
    story.append(Spacer(1, 0.3 * inch))

    # Ventas por ciudad
    story.append(Paragraph("Ventas por Ciudad", styles["Heading2"]))
    ciudad_data = [["Ciudad", "Total (Q)"]] + [
        [c["ciudad"], f"Q{c['total']:,.0f}"]
        for c in metricas["ventas_ciudad"][:5]
    ]
    t3 = Table(ciudad_data, colWidths=[4 * inch, 2 * inch])
    t3.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e85d4a")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("PADDING", (0, 0), (-1, -1), 6),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#fafafa")]),
    ]))
    story.append(t3)

    doc.build(story)
    buffer.seek(0)
    return buffer


# ─── HANDLER PRINCIPAL ─────────────────────────────────────────────────────────
def handler(event, context):
    for record in event.get("Records", []):
        message_id = record["messageId"]
        body = json.loads(record["body"])

        job_id        = body.get("job_id")
        csv_s3_key    = body.get("csv_s3_key")
        nombre_archivo = body.get("nombre_archivo", "archivo.csv")
        id_usuario    = body.get("id_usuario")

        print(f"[worker] Procesando job_id={job_id} message_id={message_id}")

        conn = None
        try:
            conn = get_db_connection()

            # ── Idempotencia: verificar que el job esté PENDIENTE ──────────────
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT estado FROM trabajos WHERE job_id = %s",
                    (job_id,)
                )
                row = cursor.fetchone()

            if not row:
                print(f"[worker] job_id={job_id} no encontrado en RDS, saltando")
                continue

            if row["estado"] != "PENDIENTE":
                print(f"[worker] job_id={job_id} ya está en estado {row['estado']}, saltando")
                continue

            # ── Marcar como PROCESANDO ─────────────────────────────────────────
            with conn.cursor() as cursor:
                cursor.execute(
                    "UPDATE trabajos SET estado = 'PROCESANDO' WHERE job_id = %s",
                    (job_id,)
                )
            conn.commit()

            # ── Leer CSV desde S3 ──────────────────────────────────────────────
            print(f"[worker] Leyendo CSV desde s3://{S3_CSV_BUCKET}/{csv_s3_key}")
            obj = s3.get_object(Bucket=S3_CSV_BUCKET, Key=csv_s3_key)
            df = pd.read_csv(obj["Body"])

            # ── Calcular métricas ──────────────────────────────────────────────
            print(f"[worker] Calculando métricas para {len(df)} registros")
            periodo = datetime.utcnow().strftime("%B %Y")
            metricas = calcular_metricas(df)

            # ── Generar PDF ────────────────────────────────────────────────────
            print(f"[worker] Generando PDF")
            pdf_buffer = generar_pdf(metricas, job_id, nombre_archivo, periodo)

            # ── Guardar PDF en S3 reportes ─────────────────────────────────────
            pdf_key = f"reports/reporte_{job_id}_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}.pdf"
            s3.put_object(
                Bucket=S3_REPORTS_BUCKET,
                Key=pdf_key,
                Body=pdf_buffer.getvalue(),
                ContentType="application/pdf"
            )
            print(f"[worker] PDF guardado en s3://{S3_REPORTS_BUCKET}/{pdf_key}")

            # ── Guardar JSON de métricas en S3 ────────────────────────────────
            json_key = f"reports/metricas_{job_id}.json"
            s3.put_object(
                Bucket=S3_REPORTS_BUCKET,
                Key=json_key,
                Body=json.dumps(metricas),
                ContentType="application/json"
            )
            print(f"[worker] Métricas guardadas en s3://{S3_REPORTS_BUCKET}/{json_key}")

            # ── Actualizar RDS → COMPLETADO e insertar en reportes ────────────
            with conn.cursor() as cursor:
                cursor.execute(
                    "UPDATE trabajos SET estado = 'COMPLETADO' WHERE job_id = %s",
                    (job_id,)
                )
                cursor.execute(
                    """
                    INSERT INTO reportes (job_id, periodo, pdf_s3_key, fecha_generado)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (job_id, periodo, pdf_key, datetime.utcnow().date())
                )
            conn.commit()

            print(f"[worker] job_id={job_id} completado exitosamente message_id={message_id}")

        except Exception as e:
            print(f"[worker] ERROR job_id={job_id}: {str(e)}")

            # ── Marcar como FALLIDO e insertar en errores ──────────────────────
            try:
                if conn:
                    with conn.cursor() as cursor:
                        cursor.execute(
                            "UPDATE trabajos SET estado = 'FALLIDO' WHERE job_id = %s",
                            (job_id,)
                        )
                        cursor.execute(
                            """
                            INSERT INTO errores (job_id, id_usuario, fecha, descripcion)
                            VALUES (%s, %s, %s, %s)
                            """,
                            (job_id, id_usuario, datetime.utcnow().date(), str(e))
                        )
                    conn.commit()
            except Exception as db_err:
                print(f"[worker] ERROR al registrar fallo en RDS: {str(db_err)}")

            raise e

        finally:
            if conn:
                conn.close()
