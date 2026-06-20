import { useState, useEffect } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Button from "../components/Button.jsx";
import Spinner from "../components/Spinner.jsx";
import { getReportMetrics, getReportDownloadUrl, IS_DEMO } from "../api/client.js";

// Datos demo — se usan solo cuando no hay backend real configurado
const DEMO_REPORT_DATA = {
  periodo: "Mayo 2026",
  total_vendido: 1245890,
  producto_top: "Laptop Pro X15",
  ciudad_top: "Guatemala",
  total_registros: 18540,
  clientes_frecuentes: 150,
  top_productos: [
    { nombre: "Laptop Pro X15 Retina",      total: 680000 },
    { nombre: "Mouse Inalámbrico Silent",   total: 520000 },
    { nombre: "Teclado Mecánico RGB G-Pro", total: 410000 },
  ],
  ventas_ciudad: [
    { ciudad: "Guatemala",         total: 840000 },
    { ciudad: "Quetzaltenango",    total: 250500 },
    { ciudad: "Antigua Guatemala", total: 165300 },
  ],
  clientes_top: [
    { nombre: "Corporación Multi-Pro", total: 40200 },
    { nombre: "Distribuidora El Sol",  total: 38800 },
  ],
  evolucion_mensual: [
    { mes: "Feb", total: 85000  },
    { mes: "Mar", total: 120000 },
    { mes: "Abr", total: 195000 },
    { mes: "May", total: 245890 },
  ],
};

export default function ReportDetail({ report, setPage }) {
  const [data, setData]       = useState(IS_DEMO ? DEMO_REPORT_DATA : null);
  const [loading, setLoading] = useState(!IS_DEMO);
  const [error, setError]     = useState("");
  const [downloading, setDownloading] = useState(false);

  useEffect(() => {
    if (IS_DEMO || !report) return;
    const load = async () => {
      try {
        // report viene de History.jsx, donde cada fila ya es un objeto
        // de la tabla `reportes` con id_reporte, job_id, periodo, etc.
        const metrics = await getReportMetrics(report.id_reporte);
        setData(metrics);
      } catch (e) {
        setError("No se pudieron cargar las métricas de este reporte.");
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [report]);

  const handleDownload = async () => {
    if (IS_DEMO) {
      alert(`Demo: aquí se descargaría el PDF del reporte ${report?.job_id || ""}`);
      return;
    }
    setDownloading(true);
    try {
      const { download_url } = await getReportDownloadUrl(report.id_reporte);
      window.open(download_url, "_blank");
    } catch (e) {
      alert("Error al obtener el enlace de descarga.");
    } finally {
      setDownloading(false);
    }
  };

  if (loading) {
    return (
      <div style={{ padding: 64, display: "flex", justifyContent: "center" }}>
        <Spinner />
      </div>
    );
  }

  if (error || !data) {
    return (
      <div style={{ textAlign: "center", padding: 64, color: C.red }}>
        <div style={{ fontSize: 40, marginBottom: 12 }}>⚠️</div>
        <div style={{ fontWeight: 600 }}>{error || "Sin datos para este reporte."}</div>
        <button onClick={() => setPage("history")} style={{ marginTop: 16, fontSize: 13, color: C.coral, background: "none", border: "none", cursor: "pointer" }}>
          ← Volver al historial
        </button>
      </div>
    );
  }

  const maxBar = data.evolucion_mensual?.length
    ? Math.max(...data.evolucion_mensual.map((m) => m.total))
    : 1;

  return (
    <div className="fade-in">
      {/* Header */}
      <div style={{ marginBottom: 24, display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <button
            onClick={() => setPage("history")}
            style={{ fontSize: 12, color: C.slateL, background: "none", border: "none", cursor: "pointer", marginBottom: 8, display: "flex", alignItems: "center", gap: 4 }}
          >
            ← Volver al historial
          </button>
          <h1 style={{ fontSize: 22, fontWeight: 800 }}>
            Reporte — <span style={{ color: C.coral }}>{report?.nombre_archivo || "Reporte"}</span>
          </h1>
          <p style={{ fontSize: 13, color: C.slateL, marginTop: 4 }}>
            Período: {data.periodo} {report?.job_id && (
              <>· Job ID: <span style={{ fontFamily: "'JetBrains Mono',monospace" }}>{report.job_id}</span></>
            )}
          </p>
        </div>
        <Button onClick={handleDownload} disabled={downloading}>
          {downloading ? "Generando enlace..." : "↓ Descargar PDF"}
        </Button>
      </div>

      {/* KPIs principales */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: 16, marginBottom: 24 }}>
        {[
          { label: "Total Vendido",         value: `Q${(data.total_vendido / 1000).toFixed(0)}k`, icon: "💰", color: C.coral },
          { label: "Producto más vendido",  value: data.producto_top,                             icon: "🏆", color: C.amber },
          { label: "Ciudad con más ventas", value: data.ciudad_top,                               icon: "📍", color: C.blue  },
          { label: "Clientes frecuentes",   value: data.clientes_frecuentes,                      icon: "👥", color: C.green },
        ].map((m, i) => (
          <Card key={i} style={{ padding: "18px 20px" }}>
            <div style={{ fontSize: 11, color: C.slateL, fontWeight: 600, marginBottom: 6 }}>
              {m.icon} {m.label}
            </div>
            <div style={{ fontSize: 18, fontWeight: 800, color: m.color, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
              {m.value}
            </div>
          </Card>
        ))}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20, marginBottom: 20 }}>
        {/* Top productos */}
        <Card style={{ padding: 20 }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 16 }}>
            🏅 Top productos más vendidos
          </h3>
          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {(data.top_productos || []).map((p, i) => (
              <div key={i} style={{ display: "flex", justifyContent: "space-between", fontSize: 13 }}>
                <span style={{ fontWeight: 500 }}>
                  <span style={{ color: C.coral, fontWeight: 700, marginRight: 6 }}>{i + 1}.</span>
                  {p.nombre}
                </span>
                <span style={{ fontWeight: 700 }}>Q{Number(p.total).toLocaleString()}</span>
              </div>
            ))}
          </div>
        </Card>

        {/* Clientes frecuentes */}
        <Card style={{ padding: 20 }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 16 }}>
            👥 Clientes más frecuentes
          </h3>
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {(data.clientes_top || []).map((c, i) => (
              <div key={i} style={{ display: "flex", justifyContent: "space-between", fontSize: 13 }}>
                <span style={{ fontWeight: 600 }}>{c.nombre}</span>
                <span style={{ fontWeight: 700, color: C.coral }}>Q{Number(c.total).toLocaleString()}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 }}>
        {/* Ventas por ciudad */}
        <Card style={{ padding: 20 }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 16 }}>
            📍 Ventas por ciudad
          </h3>
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {(data.ventas_ciudad || []).map((c, i) => (
              <div key={i} style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <span style={{ fontSize: 13, fontWeight: 600 }}>{c.ciudad}</span>
                <span style={{ fontSize: 14, fontWeight: 800, color: C.coral }}>
                  Q{Number(c.total).toLocaleString()}
                </span>
              </div>
            ))}
          </div>
        </Card>

        {/* Evolución mensual */}
        <Card style={{ padding: 20 }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 24 }}>
            📈 Análisis de Tendencia Mensual
          </h3>
          <div style={{ display: "flex", alignItems: "flex-end", gap: 14, height: 140 }}>
            {(data.evolucion_mensual || []).map((m, i) => {
              const isLast = i === data.evolucion_mensual.length - 1;
              const barH   = Math.round((m.total / maxBar) * 120);
              return (
                <div key={i} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
                  <div style={{ fontSize: 10, color: C.slateL, fontWeight: 600 }}>
                    Q{(m.total / 1000).toFixed(0)}k
                  </div>
                  <div
                    style={{
                      width: "100%",
                      height: barH,
                      borderRadius: "6px 6px 0 0",
                      background: isLast
                        ? `linear-gradient(to top, ${C.coral}, ${C.coralDk})`
                        : C.gray,
                      transition: "height 0.5s ease",
                    }}
                  />
                  <div style={{ fontSize: 11, fontWeight: 600, color: C.slateL }}>{m.mes}</div>
                </div>
              );
            })}
          </div>
        </Card>
      </div>
    </div>
  );
}