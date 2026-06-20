import { useState, useEffect } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Spinner from "../components/Spinner.jsx";
import { StatusBadge } from "../components/Badge.jsx";
import { getReports, getReportDownloadUrl, getReportCsvUrl, IS_DEMO } from "../api/client.js";
import { DEMO_REPORTS } from "../api/demo.js";

export default function History({ user, setPage, setSelectedReport }) {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch]   = useState("");
  const [periodo, setPeriodo] = useState("");

  const isReadOnly = user.rol === "auditor";
  // El backend GET /reports devuelve id_usuario, no el nombre — por eso
  // la columna "Usuario" muestra el ID en vez del nombre, salvo en modo demo.
  const showUser   = user.rol !== "analista";

  useEffect(() => {
    const load = async () => {
      try {
        if (IS_DEMO) {
          await new Promise((r) => setTimeout(r, 400));
          setReports(DEMO_REPORTS);
        } else {
          const idUsuario = user.rol === "analista" ? user.id_usuario : null;
          const data = await getReports(idUsuario);
          setReports(data.reports || []);
        }
      } catch (_) {
        setReports(IS_DEMO ? DEMO_REPORTS : []);
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

  const filtered = reports.filter((r) => {
    const matchSearch  = !search  || (r.nombre_archivo || "").toLowerCase().includes(search.toLowerCase());
    const matchPeriodo = !periodo || (r.periodo || "").includes(periodo);
    return matchSearch && matchPeriodo;
  });

  return (
    <div className="fade-in">
      <div style={{ marginBottom: 24, display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 800 }}>Historial de Reportes</h1>
          <p style={{ color: C.slateL, fontSize: 13, marginTop: 4 }}>
            Consulta y gestiona todos los trabajos de procesamiento realizados en el sistema.
          </p>
        </div>
      </div>

      <Card>
        <div style={{ padding: "16px 20px", borderBottom: `1px solid ${C.gray}`, display: "flex", gap: 12, alignItems: "center" }}>
          <div style={{ flex: 1, position: "relative" }}>
            <span style={{ position: "absolute", left: 12, top: "50%", transform: "translateY(-50%)", color: C.slateL }}>🔍</span>
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Buscar por nombre de archivo..."
              style={{ width: "100%", padding: "8px 14px 8px 36px", borderRadius: 8, border: `1.5px solid ${C.gray}`, fontSize: 13, outline: "none" }}
            />
          </div>
        </div>

        {loading ? (
          <div style={{ padding: 48, display: "flex", justifyContent: "center" }}><Spinner /></div>
        ) : (
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ background: C.grayLt }}>
                {["Archivo", ...(showUser ? ["Usuario"] : []), "Fecha de Creación", "Acciones"].map((h) => (
                  <th key={h} style={{ padding: "10px 20px", textAlign: "left", fontSize: 11, fontWeight: 700, color: C.slateL, textTransform: "uppercase", letterSpacing: "0.05em" }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ padding: 32, textAlign: "center", color: C.slateL, fontSize: 13 }}>
                    Sin resultados para los filtros aplicados.
                  </td>
                </tr>
              ) : filtered.map((r) => (
                <tr
                  key={r.id_reporte}
                  style={{ borderTop: `1px solid ${C.gray}` }}
                  onMouseEnter={(e) => (e.currentTarget.style.background = C.grayLt)}
                  onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
                >
                  <td style={{ padding: "14px 20px" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <div style={{ width: 36, height: 36, borderRadius: 8, background: C.coralLt, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 16 }}>
                        📄
                      </div>
                      <div>
                        <div style={{ fontSize: 13, fontWeight: 600 }}>{r.nombre_archivo}</div>
                        <div style={{ fontSize: 11, color: C.slateL, fontFamily: "'JetBrains Mono',monospace" }}>Job: {r.job_id}</div>
                      </div>
                    </div>
                  </td>
                  {showUser && (
                    <td style={{ padding: "14px 20px", fontSize: 13 }}>
                      {/* El backend solo devuelve id_usuario en este endpoint, no el nombre */}
                      {r.usuario || `Usuario #${r.id_usuario}`}
                    </td>
                  )}
                  <td style={{ padding: "14px 20px", fontSize: 13, color: C.slateL }}>
                    {new Date(r.fecha_generado).toLocaleString("es-GT")}
                  </td>
                  <td style={{ padding: "14px 20px" }}>
                    <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                      <button
                        onClick={() => { setSelectedReport(r); setPage("report"); }}
                        style={{ fontSize: 12, color: C.coral, fontWeight: 600, background: C.coralLt, border: "none", padding: "5px 12px", borderRadius: 6, cursor: "pointer" }}
                      >
                        👁 Ver reporte
                      </button>
                      {!isReadOnly && (
                        <button
                          onClick={() => handleDownload(r)}
                          style={{ fontSize: 12, color: C.slateL, background: C.grayLt, border: "none", padding: "5px 12px", borderRadius: 6, cursor: "pointer" }}
                        >
                          ↓ Descargar
                        </button>
                      )}
                      {isReadOnly && (
<<<<<<< HEAD
                        <button
                          onClick={async () => {
                            try {
                              const { download_url } = await getReportCsvUrl(r.id_reporte);
                              window.open(download_url, "_blank");
                            } catch (e) {
                              alert("Error al obtener el CSV original.");
                            }
                          }}
                          style={{ fontSize: 12, color: C.blue, background: C.grayLt, border: "none", padding: "5px 12px", borderRadius: 6, cursor: "pointer" }}
                        >
                          Ver CSV original
                        </button>
=======
                        <span style={{ fontSize: 11, color: C.slateL }}>Solo lectura</span>
>>>>>>> origin/main
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        <div style={{ padding: "14px 20px", borderTop: `1px solid ${C.gray}`, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ fontSize: 13, color: C.slateL }}>Mostrando {filtered.length} de {reports.length} reportes</span>
        </div>
      </Card>
    </div>
  );
}