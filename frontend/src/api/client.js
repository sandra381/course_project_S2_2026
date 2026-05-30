// ─────────────────────────────────────────────────────────────
// SPVR API Client
//
// Este archivo es el único punto de contacto entre el frontend
// y el API Gateway de AWS.
//
// Para conectar con AWS:
//   1. Corre: terraform output api_endpoint
//   2. Copia el valor en el archivo .env como VITE_API_URL
//
// Mientras VITE_API_URL esté vacío, la app usa datos demo.
// ─────────────────────────────────────────────────────────────

const API_BASE = import.meta.env.VITE_API_URL || "";

// true cuando no hay URL configurada → usa datos demo
export const IS_DEMO = !API_BASE;

// ─── Función base que hace todas las peticiones ───────────────
async function request(method, path, body = null) {
  if (IS_DEMO) {
    throw new Error("DEMO_MODE"); // las páginas capturan esto y usan datos locales
  }

  const token = localStorage.getItem("spvr_token");

  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || `Error ${res.status}`);
  }

  return res.json();
}

// ─────────────────────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────────────────────

// POST /login — recibe email y password, devuelve token + usuario
export const login = (email, password) =>
  request("POST", "/login", { email, password });

// ─────────────────────────────────────────────────────────────
// TRABAJOS (jobs)
// ─────────────────────────────────────────────────────────────

// GET /jobs — lista todos los trabajos del usuario autenticado
export const getJobs = () =>
  request("GET", "/jobs");

// GET /jobs/:job_id — detalle de un trabajo específico
export const getJob = (jobId) =>
  request("GET", `/jobs/${jobId}`);

// POST /upload — genera presigned URL para subir CSV a S3
// Devuelve: { job_id, upload_url, s3_key, status }
export const createUpload = (filename, idUsuario) =>
  request("POST", "/upload", { filename, id_usuario: idUsuario });

// Sube el archivo CSV directamente a S3 usando la presigned URL
// (esta llamada va a S3, no al API Gateway)
export const uploadFileToS3 = async (presignedUrl, file) => {
  const res = await fetch(presignedUrl, {
    method: "PUT",
    body: file,
    headers: { "Content-Type": "text/csv" },
  });
  if (!res.ok) throw new Error("Error al subir el archivo a S3");
};

// ─────────────────────────────────────────────────────────────
// REPORTES
// ─────────────────────────────────────────────────────────────

// GET /reports — historial de reportes generados
export const getReports = () =>
  request("GET", "/reports");

// GET /reports/:id/download — URL firmada para descargar el PDF
export const getReportDownloadUrl = (reportId) =>
  request("GET", `/reports/${reportId}/download`);

// POST /reports — escribe un objeto en S3 (Deliverable D del curso)
export const postReport = (data) =>
  request("POST", "/reports", data);

// ─────────────────────────────────────────────────────────────
// ERRORES
// ─────────────────────────────────────────────────────────────

// GET /errors — registro de errores (solo administrador)
export const getErrors = () =>
  request("GET", "/errors");
