// ─────────────────────────────────────────────────────────────
// Datos demo del SPVR
//
// Se usan cuando VITE_API_URL no está configurado.
// Reflejan exactamente los mockups del equipo.
// ─────────────────────────────────────────────────────────────

export const DEMO_USERS = {
  "ana@spvr.com":    { id: 1, nombre: "Ana López",       rol: "analista",      email: "ana@spvr.com" },
  "carlos@spvr.com": { id: 2, nombre: "Carlos Pérez",    rol: "gerente",       email: "carlos@spvr.com" },
  "juan@spvr.com":   { id: 3, nombre: "Juan Pérez",      rol: "vendedor",      email: "juan@spvr.com" },
  "admin@spvr.com":  { id: 4, nombre: "Admin Principal", rol: "administrador", email: "admin@spvr.com" },
  "audit@spvr.com":  { id: 5, nombre: "Auditor 01",      rol: "auditor",       email: "audit@spvr.com" },
};

export const DEMO_PASSWORD = "spvr2026";

export const DEMO_JOBS = [
  {
    job_id: "A-0024",
    nombre_archivo: "ventas_mayo_2026.csv",
    estado: "PROCESANDO",
    fecha_carga: "2026-05-24T14:30:00",
    csv_s3_key: "uploads/A-0024/ventas_mayo_2026.csv",
    usuario: "Ana López",
  },
  {
    job_id: "A-0023",
    nombre_archivo: "reporte_anual_2025_v2.csv",
    estado: "COMPLETADO",
    fecha_carga: "2026-05-23T09:15:00",
    csv_s3_key: "uploads/A-0023/reporte_anual.csv",
    usuario: "Ana López",
  },
  {
    job_id: "A-0022",
    nombre_archivo: "ventas_noreste_final.csv",
    estado: "COMPLETADO",
    fecha_carga: "2026-05-22T18:45:00",
    csv_s3_key: "uploads/A-0022/ventas_noreste.csv",
    usuario: "Ana López",
  },
  {
    job_id: "A-0021",
    nombre_archivo: "error_carga_datos.csv",
    estado: "FALLIDO",
    fecha_carga: "2026-05-22T11:20:00",
    csv_s3_key: "uploads/A-0021/error.csv",
    usuario: "Ana López",
  },
  {
    job_id: "A-0020",
    nombre_archivo: "consolidado_ventas_q1.csv",
    estado: "COMPLETADO",
    fecha_carga: "2026-05-21T10:00:00",
    csv_s3_key: "uploads/A-0020/consolidado.csv",
    usuario: "Luis Porras",
  },
];

export const DEMO_REPORTS = [
  { id_reporte: 1, job_id: "A-0023", nombre_archivo: "reporte_anual_2025_v2.csv",       usuario: "Ana López",    fecha_generado: "2026-05-23T09:15:00", estado: "COMPLETADO", periodo: "2025-12" },
  { id_reporte: 2, job_id: "A-0022", nombre_archivo: "ventas_noreste_final.csv",          usuario: "Ana López",    fecha_generado: "2026-05-22T18:45:00", estado: "COMPLETADO", periodo: "2026-05" },
  { id_reporte: 3, job_id: "A-0021", nombre_archivo: "ventas_sucursal_norte_v2.csv",      usuario: "Luis Porras",  fecha_generado: "2026-05-14T18:45:00", estado: "FALLIDO",    periodo: "-" },
  { id_reporte: 4, job_id: "A-0020", nombre_archivo: "procesamiento_masivo_clientes.csv", usuario: "Ana López",    fecha_generado: "2026-05-13T11:20:00", estado: "PROCESANDO", periodo: "2026-04" },
  { id_reporte: 5, job_id: "A-0019", nombre_archivo: "ventas_abril_final_v3.csv",         usuario: "Luis Porras",  fecha_generado: "2026-05-12T16:05:00", estado: "COMPLETADO", periodo: "2026-04" },
];

export const DEMO_ERRORS = [
  { id: "ERR-99241", job_id: "JOB-A0024", usuario: "Ana López",     rol: "ANALISTA", fecha: "2026-05-16T14:32:00", descripcion: "Error de validación en columna 'customer_id'. Tipo de dato no coincide con el esquema CSV." },
  { id: "ERR-99240", job_id: "JOB-A0022", usuario: "Carlos Pérez",  rol: "ANALISTA", fecha: "2026-05-16T12:15:00", descripcion: "Fallo en la conexión con el servidor de generación de PDF. Tiempo de espera agotado." },
  { id: "ERR-99238", job_id: "JOB-A0019", usuario: "Luis Porras",   rol: "ANALISTA", fecha: "2026-05-15T09:45:00", descripcion: "Error de lectura de archivo: el archivo 'ventas_q1.csv' está dañado o vacío." },
  { id: "ERR-99235", job_id: "JOB-A0015", usuario: "Roberto Gómez", rol: "ANALISTA", fecha: "2026-05-14T18:20:00", descripcion: "Formato de fecha incorrecto en columna 'sale_date'. Se esperaba DD/MM/YYYY." },
  { id: "ERR-99230", job_id: "JOB-A0012", usuario: "Ana López",     rol: "ANALISTA", fecha: "2026-05-14T11:05:00", descripcion: "Símbolo de moneda no reconocido en campo 'unit_price'. Se esperaba 'Q'." },
];

export const DEMO_SELLER = {
  total_vendido: 245890,
  productos_vendidos: 1540,
  clientes_atendidos: 48,
  ranking: 3,
  total_vendedores: 25,
  delta_ventas: "+15%",
  delta_productos: "+8.2%",
  delta_clientes: "+5 nuevos clientes",
  productos: [
    { nombre: "Laptop Pro X15 Retina",      cantidad: 25,  total: 187500 },
    { nombre: "Mouse Inalámbrico Silent",   cantidad: 120, total: 14400  },
    { nombre: "Teclado Mecánico RGB G-Pro", cantidad: 45,  total: 22500  },
    { nombre: "Monitor curvo 27\" 4K",      cantidad: 12,  total: 18600  },
    { nombre: "Webcam HD Pro 1080p",        cantidad: 38,  total: 2890   },
  ],
  evolucion_mensual: [
    { mes: "Feb", total: 85000  },
    { mes: "Mar", total: 120000 },
    { mes: "Abr", total: 195000 },
    { mes: "May", total: 245890 },
  ],
};
