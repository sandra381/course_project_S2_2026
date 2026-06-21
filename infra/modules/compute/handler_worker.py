import json
import os
import io
import boto3
import pymysql
import pandas as pd
from datetime import datetime
from botocore.client import Config
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
SES_SENDER_EMAIL  = os.environ["SES_SENDER_EMAIL"]

# Forzamos Signature Version 4 — requerido porque el bucket usa
# encriptación SSE-KMS (Delivery 5, Deliverable B). Sin esto, las
# presigned URLs generadas fallan con "Requests specifying Server
# Side Encryption with AWS KMS managed keys require AWS Signature Version 4".
s3  = boto3.client("s3", config=Config(signature_version="s3v4"))
sqs = boto3.client("sqs")
ses = boto3.client("ses")

# ─── SECRETS MANAGER — contraseña de base de datos ────────────────────────────
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


# ─── ENVIAR CORREO — reporte listo ─────────────────────────────────────────────
# Modo SANDBOX de SES: tanto SES_SENDER_EMAIL como destinatario_email deben
# estar verificados en la consola de AWS, o el envío falla con MessageRejected.
# Este envío va dentro de su propio try/except — si falla, el job de
# generación del reporte NO debe marcarse como fallido por esto.
def enviar_correo_reporte_listo(destinatario_email, nombre_usuario, nombre_archivo, job_id, download_url):
    try:
        ses.send_email(
            Source=SES_SENDER_EMAIL,
            Destination={"ToAddresses": [destinatario_email]},
            Message={
                "Subject": {
                    "Data": f"Tu reporte de {nombre_archivo} ya está listo"
                },
                "Body": {
                    "Text": {
                        "Data": (
                            f"Hola {nombre_usuario},\n\n"
                            f"El reporte correspondiente al archivo '{nombre_archivo}' "
                            f"(Job ID: {job_id}) ha sido generado exitosamente.\n\n"
                            f"Podés descargarlo directamente desde este enlace "
                            f"(válido por 30 minutos):\n{download_url}\n\n"
                            f"Saludos,\nSistema SPVR"
                        )
                    }
                }
            }
        )
        print(f"[worker] Correo enviado a {destinatario_email} para job_id={job_id}")
    except Exception as e:
        print(f"[worker] ADVERTENCIA: no se pudo enviar correo a {destinatario_email}: {str(e)}")


# ─── CALCULAR METRICAS DEL CSV ─────────────────────────────────────────────────
def calcular_metricas(df):
    total_vendido = float((df["quantity"] * df["unit_price"]).sum())

    top_productos = (
        df.groupby("product_name")
        .apply(lambda x: (x["quantity"] * x["unit_price"]).sum())
        .sort_values(ascending=False)
        .head(5)
    )
    producto_top = top_productos.index[0] if len(top_productos) > 0 else ""

    ventas_ciudad = (
        df.groupby("city")
        .apply(lambda x: (x["quantity"] * x["unit_price"]).sum())
        .sort_values(ascending=False)
    )
    ciudad_top = ventas_ciudad.index[0] if len(ventas_ciudad) > 0 else ""

    top_clientes = (
        df.groupby(["customer_id", "customer_name"])
        .apply(lambda x: (x["quantity"] * x["unit_price"]).sum())
        .sort_values(ascending=False)
        .head(5)
        .reset_index()
    )

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

    story.append(Paragraph(f"Reporte de Ventas — {nombre_archivo}", styles["Title"]))
    story.append(Paragraph(f"Período: {periodo} | Job ID: {job_id} | Generado: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}", styles["Normal"]))
    story.append(Spacer(1, 0.3 * inch))

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

def generar_reportes_vendedores(df, job_id, periodo, conn):
    if "salesperson_name" not in df.columns:
        print("[worker] CSV sin columna salesperson_name, se omite reporte de vendedores")
        return

    df = df.copy()
    df["total_linea"] = df["quantity"] * df["unit_price"]

    # Ranking general de este CSV — total vendido por cada vendedor
    ranking = (
        df.groupby("salesperson_name")["total_linea"]
        .sum()
        .sort_values(ascending=False)
    )
    ranking_total = len(ranking)

    for vendedor in df["salesperson_name"].unique():
        try:
            df_v = df[df["salesperson_name"] == vendedor]

            total_vendido      = float(df_v["total_linea"].sum())
            productos_vendidos = int(df_v["quantity"].sum())
            clientes_atendidos = int(df_v["customer_id"].nunique())
            ranking_posicion    = int(list(ranking.index).index(vendedor) + 1)

            top_productos = (
                df_v.groupby("product_name")["total_linea"]
                .sum()
                .sort_values(ascending=False)
                .head(10)
            )

            metricas_vendedor = {
                "nombre_vendedor": vendedor,
                "periodo": periodo,
                "total_vendido": total_vendido,
                "productos_vendidos": productos_vendidos,
                "clientes_atendidos": clientes_atendidos,
                "ranking_posicion": ranking_posicion,
                "ranking_total": ranking_total,
                "top_productos": [
                    {"nombre": n, "total": float(t)} for n, t in top_productos.items()
                ],
            }

            json_key = f"reports/vendedor_{job_id}_{vendedor.replace(' ', '_')}.json"
            s3.put_object(
                Bucket=S3_REPORTS_BUCKET,
                Key=json_key,
                Body=json.dumps(metricas_vendedor),
                ContentType="application/json"
            )

            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO reportes_vendedor
                        (job_id, nombre_vendedor, periodo, total_vendido,
                         productos_vendidos, clientes_atendidos, json_s3_key, fecha_generado)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    job_id, vendedor, periodo, total_vendido,
                    productos_vendidos, clientes_atendidos, json_key, datetime.utcnow()
                ))
            conn.commit()

            print(f"[worker] Reporte de vendedor generado: {vendedor} (job_id={job_id})")

        except Exception as e:
            # Un error en UN vendedor no debe afectar a los demás ni al job principal.
            print(f"[worker] ADVERTENCIA: no se pudo generar reporte para vendedor {vendedor}: {str(e)}")

# ─── HANDLER PRINCIPAL ─────────────────────────────────────────────────────────
def handler(event, context):
    for record in event.get("Records", []):
        message_id = record["messageId"]
        body = json.loads(record["body"])

        job_id         = body.get("job_id")
        csv_s3_key     = body.get("csv_s3_key")
        nombre_archivo = body.get("nombre_archivo", "archivo.csv")
        id_usuario     = body.get("id_usuario")

        print(f"[worker] Procesando job_id={job_id} message_id={message_id}")

        conn = None
        try:
            conn = get_db_connection()

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

            with conn.cursor() as cursor:
                cursor.execute(
                    "UPDATE trabajos SET estado = 'PROCESANDO' WHERE job_id = %s",
                    (job_id,)
                )
            conn.commit()

            print(f"[worker] Leyendo CSV desde s3://{S3_CSV_BUCKET}/{csv_s3_key}")
            obj = s3.get_object(Bucket=S3_CSV_BUCKET, Key=csv_s3_key)
            df = pd.read_csv(obj["Body"])

            print(f"[worker] Calculando métricas para {len(df)} registros")
            periodo = datetime.utcnow().strftime("%B %Y")
            metricas = calcular_metricas(df)

            print(f"[worker] Generando PDF")
            pdf_buffer = generar_pdf(metricas, job_id, nombre_archivo, periodo)

            pdf_key = f"reports/reporte_{job_id}_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}.pdf"
            s3.put_object(
                Bucket=S3_REPORTS_BUCKET,
                Key=pdf_key,
                Body=pdf_buffer.getvalue(),
                ContentType="application/pdf"
            )
            print(f"[worker] PDF guardado en s3://{S3_REPORTS_BUCKET}/{pdf_key}")

            json_key = f"reports/metricas_{job_id}.json"
            s3.put_object(
                Bucket=S3_REPORTS_BUCKET,
                Key=json_key,
                Body=json.dumps(metricas),
                ContentType="application/json"
            )
            print(f"[worker] Métricas guardadas en s3://{S3_REPORTS_BUCKET}/{json_key}")

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
                    (job_id, periodo, pdf_key, datetime.utcnow())
                )

                # ── Obtener email y nombre del usuario para la notificación ──
                cursor.execute(
                    "SELECT nombre, email FROM usuarios WHERE id_usuario = %s",
                    (id_usuario,)
                )
                usuario = cursor.fetchone()

            conn.commit()

            # ── Generar link de descarga directo (válido 30 minutos) ──────────
            download_url = s3.generate_presigned_url(
                "get_object",
                Params={"Bucket": S3_REPORTS_BUCKET, "Key": pdf_key},
                ExpiresIn=1800
            )

            # ── Enviar correo de "reporte listo" ──────────────────────────────
            if usuario:
                enviar_correo_reporte_listo(
                    destinatario_email=usuario["email"],
                    nombre_usuario=usuario["nombre"],
                    nombre_archivo=nombre_archivo,
                    job_id=job_id,
                    download_url=download_url
                )
            else:
                print(f"[worker] No se encontró usuario id_usuario={id_usuario}, no se envía correo")

                # ── Generar reportes individuales por vendedor (si aplica) ───────
            try:
                generar_reportes_vendedores(df, job_id, periodo, conn)
            except Exception as e:
                # No debe afectar el resultado del job principal si esto falla.
                print(f"[worker] ADVERTENCIA: error generando reportes de vendedores: {str(e)}")
                    
            print(f"[worker] job_id={job_id} completado exitosamente message_id={message_id}")

        except Exception as e:
            error_message = str(e)
            print(f"[worker] ERROR job_id={job_id}: {error_message}")

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
                            (job_id, id_usuario, datetime.utcnow(), error_message)
                        )
                    conn.commit()
            except Exception as db_err:
                print(f"[worker] ERROR al registrar fallo en RDS: {str(db_err)}")

            raise Exception(error_message)

        finally:
            if conn:
                conn.close()