import { useState, useEffect } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Button from "../components/Button.jsx";
import Spinner from "../components/Spinner.jsx";
import { StatusBadge } from "../components/Badge.jsx";
import { getJobs, getReports, getReportDownloadUrl, IS_DEMO } from "../api/client.js";
import { DEMO_JOBS } from "../api/demo.js";

export default function Dashboard({ user, setPage, setSelectedJob, setSelectedReport }) {
  const [jobs, setJobs]               = useState([]);
  const [reportsByJobId, setReportsByJobId] = useState({});
  const [loading, setLoading]         = useState(true);
  const [error, setError]             = useState("");

  useEffect(() => {
    const load = async () => {
      try {
        if (IS_DEMO) {
          await new Promise((r) => setTimeout(r, 500));
          setJobs(DEMO_JOBS);
        } else {
          const [jobsData, reportsData] = await Promise.all([getJobs(), getReports()]);
          setJobs(jobsData.jobs || []);

          const map = {};
          (reportsData.reports || []).forEach((r) => { map[r.job_id] = r; });
          setReportsByJobId(map);
        }
      } catch (e) {
        setError("No se pudieron cargar los trabajos.");
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const handleDownload = async (report) => {
    if (IS_DEMO) {
      alert(`Demo: aquí se descargaría el PDF del reporte ${report.job_id}`);
      return;
    }
    try {
      const { download_url } = await getReportDownloadUrl(report.id_reporte);
      window.open(download_url, "_blank");
    } catch (e) {
      alert("Error al obtener el enlace de descarga.");
    }
  };

  const completed  = jobs.filter((j) => j.estado === "COMPLETADO").length;
  const processing = jobs.filter((j) => ["PROCESANDO", "PENDIENTE"].includes(j.estado)).length;
  const failed      = jobs.filter((j) => j.estado === "FALLIDO").length;

  return (
    <div className="fade-in">
      <div style={{ marginBottom: 28, display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 800 }}>
            ¡Hola de nuevo, {user.nombre.split(" ")[0]}! 👋
          </h1>
          <p style={{ color: C.slateL, fontSize: 13, marginTop: 4 }}>
            Aquí tienes un resumen de la actividad de procesamiento de hoy.
          </p>
        </div>
        <Button onClick={() => setPage("upload")}>↑ Cargar nuevo CSV</Button>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 16, marginBottom: 28 }}>
        {[
          { label: "Reportes Generados", value: completed,  icon: "📈", color: C.coral },
          { label: "En Procesamiento",   value: processing, icon: "⏳", color: C.amber },
          { label: "Con Error",          value: failed,     icon: "⚠️", color: C.red   },
        ].map((m, i) => (
          <Card key={i} style={{ padding: "20px 24px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div>
              <div style={{ fontSize: 12, color: C.slateL, fontWeight: 600, marginBottom: 4 }}>{m.label}</div>
              <div style={{ fontSize: 32, fontWeight: 800, color: m.color }}>{m.value}</div>
            </div>
            <span style={{ fontSize: 30 }}>{m.icon}</span>
          </Card>
        ))}
      </div>

      <Card>
        <div style={{ padding: "18px 24px 14px", display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: `1px solid ${C.gray}` }}>
          <h2 style={{ fontSize: 16, fontWeight: 700 }}>Mis trabajos recientes</h2>
          <button
            onClick={() => setPage("history")}
            style={{ fontSize: 12, color: C.coral, background: "none", border: "none", cursor: "pointer", fontWeight: 600 }}
          >
            Ver todo el historial →
          </button>
        </div>

        {loading ? (
          <div style={{ padding: 48, display: "flex", justifyContent: "center" }}>
            <Spinner />
          </div>
        ) : error ? (
          <div style={{ padding: 24, color: C.red, fontSize: 13 }}>⚠️ {error}</div>
        ) : jobs.length === 0 ? (
          <div style={{ padding: 32, textAlign: "center", color: C.slateL, fontSize: 13 }}>
            No hay trabajos todavía. Subí un CSV para empezar.
          </div>
        ) : (
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ background: C.grayLt }}>
                {["Archivo", "ID Único", "Fecha de Carga", "Estado", "Acciones"].map((h) => (
                  <th key={h} style={{ padding: "10px 20px", textAlign: "left", fontSize: 11, fontWeight: 700, color: C.slateL, textTransform: "uppercase", letterSpacing: "0.05em" }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {jobs.map((j) => {
                const report = reportsByJobId[j.job_id];
                return (
                  <tr
                    key={j.job_id}
                    style={{ borderTop: `1px solid ${C.gray}` }}
                    onMouseEnter={(e) => (e.currentTarget.style.background = C.grayLt)}
                    onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
                  >
                    <td style={{ padding: "14px 20px" }}>
                      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                        <span style={{ fontSize: 18 }}>📄</span>
                        <span style={{ fontSize: 13, fontWeight: 600 }}>{j.nombre_archivo}</span>
                      </div>
                    </td>
                    <td style={{ padding: "14px 20px" }}>
                      <span style={{ fontFamily: "'JetBrains Mono',monospace", fontSize: 12, color: C.slateL }}>
                        {j.job_id}
                      </span>
                    </td>
                    <td style={{ padding: "14px 20px", fontSize: 13, color: C.slateL }}>
                      {new Date(j.fecha_carga).toLocaleString("es-GT", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })}
                    </td>
                    <td style={{ padding: "14px 20px" }}>
                      <StatusBadge estado={j.estado} />
                    </td>
                    <td style={{ padding: "14px 20px" }}>
                      <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                        {j.estado === "COMPLETADO" && report && (
                          <>
                            <button
                              onClick={() => { setSelectedReport(report); setPage("report"); }}
                              style={{ fontSize: 12, color: C.coral, fontWeight: 600, background: C.coralLt, border: "none", padding: "5px 12px", borderRadius: 6, cursor: "pointer" }}
                            >
                              👁 Ver reporte
                            </button>
                            <button
                              onClick={() => handleDownload(report)}
                              style={{ fontSize: 12, color: C.slateL, background: C.grayLt, border: "none", padding: "5px 12px", borderRadius: 6, cursor: "pointer" }}
                            >
                              ↓ Descargar
                            </button>
                          </>
                        )}
                        {j.estado === "COMPLETADO" && !report && (
                          <span style={{ fontSize: 11, color: C.slateL }}>Sin reporte vinculado</span>
                        )}
                        {(j.estado === "PROCESANDO" || j.estado === "PENDIENTE") && (
                          <button
                            onClick={() => { setSelectedJob(j); setPage("status"); }}
                            style={{ fontSize: 12, color: C.amber, fontWeight: 600, background: C.amberLt, border: "none", padding: "5px 12px", borderRadius: 6, cursor: "pointer" }}
                          >
                            ⏳ Ver estado
                          </button>
                        )}
                        {j.estado === "FALLIDO" && (
                          <button
                            onClick={() => setPage("errors")}
                            style={{ fontSize: 12, color: C.red, fontWeight: 600, background: C.redLt, border: "none", padding: "5px 12px", borderRadius: 6, cursor: "pointer" }}
                          >
                            ⚠️ Ver error
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}
