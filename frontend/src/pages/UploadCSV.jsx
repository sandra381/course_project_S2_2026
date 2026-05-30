import { useState, useRef } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Button from "../components/Button.jsx";
import Spinner from "../components/Spinner.jsx";
import { createUpload, uploadFileToS3, IS_DEMO } from "../api/client.js";

const REQUIRED_COLUMNS = [
  "sale_id", "sale_date", "product_name", "quantity",
  "unit_price", "city", "salesperson_name", "customer_id", "customer_name",
];

export default function UploadCSV({ user, setPage, setSelectedJob }) {
  const [file, setFile]           = useState(null);
  const [dragging, setDragging]   = useState(false);
  const [validError, setValidError] = useState("");
  const [uploading, setUploading] = useState(false);
  const [success, setSuccess]     = useState(false);
  const fileRef = useRef();

  // Valida nombre y extensión del archivo
  const validateFile = (f) => {
    if (!f.name.endsWith(".csv")) {
      setValidError("Solo se admiten archivos en formato .csv");
      setFile(null);
      return;
    }
    setFile(f);
    setValidError("");
  };

  // Valida las columnas del CSV leyendo la primera línea
  const validateColumns = async (f) => {
    const text  = await f.text();
    const first = text.split("\n")[0];
    const cols  = first.split(",").map((c) => c.trim().toLowerCase().replace(/"/g, ""));
    const missing = REQUIRED_COLUMNS.filter((c) => !cols.includes(c));
    return missing;
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setDragging(false);
    const f = e.dataTransfer.files[0];
    if (f) validateFile(f);
  };

  const handleUpload = async () => {
    if (!file) return;
    setUploading(true);
    setValidError("");

    try {
      // 1. Validar columnas del CSV
      const missing = await validateColumns(file);
      if (missing.length > 0) {
        setValidError(`Columnas faltantes: ${missing.join(", ")}`);
        setUploading(false);
        return;
      }

      let job;

      if (IS_DEMO) {
        // Modo demo: simula el proceso
        await new Promise((r) => setTimeout(r, 1000));
        job = {
          job_id: `A-${Math.floor(Math.random() * 900 + 100)}`,
          nombre_archivo: file.name,
          estado: "PROCESANDO",
          fecha_carga: new Date().toISOString(),
        };
      } else {
        // Modo real:
        // 2. Pedir presigned URL al API Gateway
        const { upload_url, job_id, s3_key } = await createUpload(file.name, user.id);
        // 3. Subir archivo directo a S3 con la presigned URL
        await uploadFileToS3(upload_url, file);
        job = { job_id, nombre_archivo: file.name, estado: "PROCESANDO", fecha_carga: new Date().toISOString() };
      }

      setSuccess(true);
      setSelectedJob(job);
      setTimeout(() => setPage("status"), 1500);
    } catch (e) {
      setValidError(e.message || "Error al subir el archivo.");
      setUploading(false);
    }
  };

  return (
    <div className="fade-in">
      <div style={{ marginBottom: 28 }}>
        <h1 style={{ fontSize: 22, fontWeight: 800 }}>Cargar archivo CSV de ventas</h1>
        <p style={{ color: C.slateL, fontSize: 13, marginTop: 4 }}>
          Sube tus datos de ventas para iniciar el procesamiento y generación de reportes.
        </p>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "280px 1fr", gap: 24, alignItems: "start" }}>

        {/* Panel izquierdo: columnas requeridas */}
        <Card style={{ padding: 20 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 12, color: C.coral }}>
            <span>ℹ️</span>
            <span style={{ fontWeight: 700, fontSize: 13 }}>Columnas requeridas</span>
          </div>
          <p style={{ fontSize: 11, color: C.slateL, marginBottom: 14, lineHeight: 1.6 }}>
            Asegúrate de que tu archivo CSV contenga exactamente los siguientes encabezados para un procesamiento exitoso.
          </p>
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            {REQUIRED_COLUMNS.map((col) => (
              <div
                key={col}
                style={{ display: "flex", alignItems: "center", gap: 8, padding: "6px 10px", borderRadius: 8, background: C.grayLt, fontSize: 12 }}
              >
                <span>📋</span>
                <span style={{ fontFamily: "'JetBrains Mono',monospace", fontWeight: 500 }}>{col}</span>
              </div>
            ))}
          </div>
          <p style={{ fontSize: 10, color: C.slateL, marginTop: 12, lineHeight: 1.5 }}>
            * El orden de las columnas no es relevante, pero los nombres deben coincidir exactamente.
          </p>
        </Card>

        {/* Panel derecho: zona de carga */}
        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <div
            onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
            onDragLeave={() => setDragging(false)}
            onDrop={handleDrop}
            onClick={() => fileRef.current?.click()}
            style={{
              border: `2px dashed ${dragging ? C.coral : file ? C.green : C.gray}`,
              borderRadius: 16,
              padding: "52px 32px",
              textAlign: "center",
              cursor: "pointer",
              background: dragging ? C.coralLt : file ? C.greenLt : C.grayLt,
              transition: "all 0.2s",
            }}
          >
            <input
              ref={fileRef}
              type="file"
              accept=".csv"
              style={{ display: "none" }}
              onChange={(e) => e.target.files[0] && validateFile(e.target.files[0])}
            />
            <div style={{ fontSize: 42, marginBottom: 12 }}>{file ? "✅" : "⬆️"}</div>
            {file ? (
              <>
                <div style={{ fontWeight: 700, fontSize: 15, color: C.green }}>{file.name}</div>
                <div style={{ fontSize: 12, color: C.slateL, marginTop: 4 }}>
                  {(file.size / 1024).toFixed(1)} KB — listo para procesar
                </div>
              </>
            ) : (
              <>
                <div style={{ fontWeight: 700, fontSize: 15, color: C.slate }}>
                  Arrastra tu archivo CSV aquí o haz clic para seleccionar
                </div>
                <div style={{ fontSize: 12, color: C.slateL, marginTop: 6 }}>
                  Solo se admiten archivos en formato <strong>.csv</strong>
                </div>
              </>
            )}
          </div>

          {/* Errores de validación */}
          {validError && (
            <div style={{ padding: "14px 16px", borderRadius: 10, background: C.redLt, border: `1px solid ${C.red}30` }}>
              <div style={{ fontWeight: 700, fontSize: 13, color: C.red, marginBottom: 4 }}>❌ Error de Validación</div>
              <div style={{ fontSize: 12, color: C.red }}>{validError}</div>
              <div style={{ fontSize: 11, color: C.slateL, marginTop: 6 }}>
                Por favor, verifica el archivo y vuelve a intentarlo.
              </div>
            </div>
          )}

          {/* Éxito */}
          {success && (
            <div style={{ padding: "12px 16px", borderRadius: 10, background: C.greenLt, color: C.green, fontSize: 13, fontWeight: 600 }}>
              ✅ Archivo recibido correctamente. Redirigiendo al estado del trabajo...
            </div>
          )}

          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 6 }}>
            <Button onClick={handleUpload} disabled={!file || uploading || success} size="lg">
              {uploading ? <><Spinner size={16} /> Subiendo...</> : "Procesar Archivo →"}
            </Button>
            <p style={{ fontSize: 11, color: C.slateL }}>
              Al procesar, el sistema validará la estructura y tipo de datos.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
