import { useState, useEffect } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Spinner from "../components/Spinner.jsx";
import Button from "../components/Button.jsx";
import { StatusBadge } from "../components/Badge.jsx";
import { getReports, getReportDownloadUrl, IS_DEMO } from "../api/client.js";
import { DEMO_REPORTS } from "../api/demo.js";

export default function History({ user, setPage, setSelectedReport }) {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch]   = useState("");
  const [periodo, setPeriodo] = useState("");

  // Solo el auditor ve todos los reportes; el resto ve los suyos
  const isReadOnly = user.rol === "auditor";
  const showUser   = user.rol !== "analista";

  useEffect(() => {
    const load = async () => {
      try {
        if (IS_DEMO) {
          await new Promise((r) => setTimeout(r, 400));
          setReports(DEMO_REPORTS);
        } else {
          const data = await getReports();
          setReports(data.reports);
        }
      } catch (_) {
        setReports(DEMO_REPORTS);
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
    const matchSearch  = !search  || r.nombre_archivo.toLowerCase().includes(search.toLowerCase());
    const matchPeriodo = !periodo || r.periodo.includes(periodo);
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
        <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 16px", borderRadius: 10, border: `1.5px solid ${C.gray}`, fontSize: 13, background: C.white }}>
          📅 Últimos 30 días
        </div>
      </div>

      {/* Totales */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 16, marginBottom: 24 }}>
        {[
          { label: "Total Procesados", value: "1,284", icon: "✅", color: C.green },
          { label: "En Espera",        value: "12",    icon: "⏳", color: C.amber },
          { label: "Errores Críticos", value: "3",     icon: "🚨", color: C.red   },
        ].map((m, i) => (
          <Card key={i} style={{ padding: "16px 20px", display: "flex", alignItems: "center", gap: 16 }}>
            <span style={{ fontSize: 28 }}>{m.icon}</span>
            <div>
              <div style={{ fontSize: 11, color: C.slateL, fontWeight: 600 }}>{m.label}</div>
              <div style={{ fontSize: 24, fontWeight: 800, color: m.color }}>{m.value}</div>
            </div>
          </Card>
        ))}
      </div>

      <Card>
        {/* Filtros */}
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
          <select
            value={periodo}
            onChange={(e) => setPeriodo(e.target.value)}
            style={{ padding: "8px 14px", borderRadius: 8, border: `1.5px solid ${C.gray}`, fontSize: 13, outline: "none", background: C.white }}
          >
            <option value="">Todos los períodos</option>
            <option value="2026-05">Mayo 2026</option>
            <option value="2026-04">Abril 2026</option>
            <option value="2025-12">Dic 2025</option>
          </select>
        </div>

        {/* Tabla */}
        {loading ? (
          <div style={{ padding: 48, display: "flex", justifyContent: "center" }}><Spinner /></div>
        ) : (
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ background: C.grayLt }}>
                {["Archivo", ...(showUser ? ["Usuario"] : []), "Fecha de Creación", "Estado", "Acciones"].map((h) => (
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
                        <div style={{ fontSize: 11, color: C.slateL, fontFamily: "'JetBrains Mono',monospace" }}>ID: {r.job_id}</div>
                      </div>
                    </div>
                  </td>
                  {showUser && (
                    <td style={{ padding: "14px 20px", fontSize: 13 }}>{r.usuario}</td>
                  )}
                  <td style={{ padding: "14px 20px", fontSize: 13, color: C.slateL }}>
                    {new Date(r.fecha_generado).toLocaleString("es-GT")}
                  </td>
                  <td style={{ padding: "14px 20px" }}>
                    <StatusBadge estado={r.estado} />
                  </td>
                  <td style={{ padding: "14px 20px" }}>
                    <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                      {r.estado === "COMPLETADO" && (
                        <button
                          onClick={() => { setSelectedReport(r); setPage("report"); }}
                          style={{ fontSize: 12, color: C.coral, fontWeight: 600, background: C.coralLt, border: "none", padding: "5px 12px", borderRadius: 6, cursor: "pointer" }}
                        >
                          👁 Ver reporte
                        </button>
                      )}
                      {r.estado === "COMPLETADO" && !isReadOnly && (
                        <button
                          onClick={() => handleDownload(r)}
                          style={{ fontSize: 12, color: C.slateL, background: C.grayLt, border: "none", padding: "5px 12px", borderRadius: 6, cursor: "pointer" }}
                        >
                          ↓ Descargar
                        </button>
                      )}
                      {r.estado === "COMPLETADO" && isReadOnly && (
                        <span style={{ fontSize: 11, color: C.slateL }}>Solo lectura</span>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        {/* Paginación */}
        <div style={{ padding: "14px 20px", borderTop: `1px solid ${C.gray}`, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ fontSize: 13, color: C.slateL }}>Mostrando 1-{filtered.length} de {reports.length} reportes</span>
          <div style={{ display: "flex", gap: 4 }}>
            {[1, 2, 3].map((p) => (
              <button
                key={p}
                style={{
                  width: 32, height: 32, borderRadius: 8,
                  border: `1.5px solid ${p === 1 ? C.coral : C.gray}`,
                  background: p === 1 ? C.coral : "transparent",
                  color: p === 1 ? "#fff" : C.slateL,
                  fontSize: 13, fontWeight: 600, cursor: "pointer",
                }}
              >
                {p}
              </button>
            ))}
            <button style={{ padding: "0 12px", height: 32, borderRadius: 8, border: `1.5px solid ${C.gray}`, background: "transparent", color: C.slateL, fontSize: 13, cursor: "pointer" }}>
              Siguiente →
            </button>
          </div>
        </div>
      </Card>
    </div>
  );
}
