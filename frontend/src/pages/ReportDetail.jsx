import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Button from "../components/Button.jsx";

// Datos demo del reporte — en producción vendrían del API Gateway
// junto con el job_id del reporte seleccionado
const DEMO_REPORT_DATA = {
  periodo: "Mayo 2026",
  fecha: "24 May 2026, 14:30",
  archivo: "ventas_mayo_2026.csv",
  job_id: "A-0023",
  total_vendido: 1245890,
  producto_top: "Laptop Pro X15",
  ciudad_top: "Guatemala",
  total_registros: 18540,
  ciudades_analizadas: 12,
  clientes_frecuentes: 150,
  top_productos: [
    { nombre: "Laptop Pro X15 Retina",      total: 680000, porcentaje: 54 },
    { nombre: "Mouse Inalámbrico Silent",   total: 520000, porcentaje: 41 },
    { nombre: "Teclado Mecánico RGB G-Pro", total: 410000, porcentaje: 32 },
    { nombre: "Monitor curvo 27\" 4K",      total: 390000, porcentaje: 31 },
    { nombre: "Webcam HD Pro 1080p",        total: 310000, porcentaje: 24 },
  ],
  ventas_ciudad: [
    { ciudad: "Guatemala",      total: 840000, crecimiento: "+15%" },
    { ciudad: "Quetzaltenango", total: 250500, crecimiento: "+8%"  },
    { ciudad: "Antigua Guatemala", total: 165300, crecimiento: "+12%" },
    { ciudad: "Escuintla",      total: 66400,  crecimiento: "-2%"  },
    { ciudad: "Mazatenango",    total: 62100,  crecimiento: "+5%"  },
  ],
  clientes_top: [
    { nombre: "Corporación Multi-Pro", id: "C-1624", pedidos: 12, total: 40200 },
    { nombre: "Distribuidora El Sol",  id: "C-2041", pedidos: 9,  total: 38800 },
    { nombre: "Almacenes Unidos",      id: "C-4944", pedidos: 15, total: 31500 },
    { nombre: "Suministros Globales",  id: "C-4422", pedidos: 7,  total: 28150 },
    { nombre: "Inversiones del Norte", id: "C-1922", pedidos: 10, total: 22400 },
  ],
  evolucion_mensual: [
    { mes: "Ene", total: 70000  },
    { mes: "Feb", total: 95000  },
    { mes: "Mar", total: 140000 },
    { mes: "Abr", total: 195000 },
    { mes: "May", total: 245890 },
  ],
};

export default function ReportDetail({ report, setPage }) {
  // Si viene un reporte seleccionado real usamos sus datos,
  // si no, usamos el demo
  const data = DEMO_REPORT_DATA;
  const maxBar = Math.max(...data.evolucion_mensual.map((m) => m.total));

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
            Reporte — <span style={{ color: C.coral }}>{data.archivo}</span>
          </h1>
          <p style={{ fontSize: 13, color: C.slateL, marginTop: 4 }}>
            Período: {data.periodo} · Generado el {data.fecha} · Job ID:{" "}
            <span style={{ fontFamily: "'JetBrains Mono',monospace" }}>{data.job_id}</span>
          </p>
        </div>
        <Button>↓ Descargar PDF</Button>
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

      {/* Fila: Top productos + Clientes frecuentes */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20, marginBottom: 20 }}>

        {/* Top productos */}
        <Card style={{ padding: 20 }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 16 }}>
            🏅 Top productos más vendidos
          </h3>
          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {data.top_productos.map((p, i) => (
              <div key={i}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4, fontSize: 13 }}>
                  <span style={{ fontWeight: 500 }}>
                    <span style={{ color: C.coral, fontWeight: 700, marginRight: 6 }}>{i + 1}.</span>
                    {p.nombre}
                  </span>
                  <span style={{ fontWeight: 700 }}>Q{p.total.toLocaleString()}</span>
                </div>
                {/* Barra de porcentaje */}
                <div style={{ height: 6, background: C.grayLt, borderRadius: 3, overflow: "hidden" }}>
                  <div
                    style={{
                      height: "100%",
                      width: `${p.porcentaje}%`,
                      background: `linear-gradient(to right, ${C.coral}, ${C.coralDk})`,
                      borderRadius: 3,
                    }}
                  />
                </div>
              </div>
            ))}
          </div>
        </Card>

        {/* Clientes frecuentes */}
        <Card style={{ padding: 20 }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 16 }}>
            👥 Clientes más frecuentes
          </h3>
          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
            <div style={{ display: "grid", gridTemplateColumns: "1fr auto auto", gap: 8, padding: "0 0 8px", borderBottom: `1px solid ${C.gray}` }}>
              {["Cliente", "Pedidos", "Total"].map((h) => (
                <span key={h} style={{ fontSize: 10, fontWeight: 700, color: C.slateL, textTransform: "uppercase" }}>{h}</span>
              ))}
            </div>
            {data.clientes_top.map((c, i) => (
              <div
                key={i}
                style={{ display: "grid", gridTemplateColumns: "1fr auto auto", gap: 8, padding: "10px 0", borderBottom: `1px solid ${C.grayLt}` }}
              >
                <div>
                  <div style={{ fontSize: 13, fontWeight: 600 }}>{c.nombre}</div>
                  <div style={{ fontSize: 10, color: C.slateL, fontFamily: "'JetBrains Mono',monospace" }}>{c.id}</div>
                </div>
                <span style={{ fontSize: 13, color: C.slateL, alignSelf: "center" }}>{c.pedidos}</span>
                <span style={{ fontSize: 13, fontWeight: 700, color: C.coral, alignSelf: "center" }}>
                  Q{c.total.toLocaleString()}
                </span>
              </div>
            ))}
            <button style={{ marginTop: 8, fontSize: 12, color: C.coral, background: "none", border: "none", cursor: "pointer", fontWeight: 600, textAlign: "left" }}>
              Ver todos los clientes →
            </button>
          </div>
        </Card>
      </div>

      {/* Fila: Ventas por ciudad + Evolución mensual */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 }}>

        {/* Ventas por ciudad */}
        <Card style={{ padding: 20 }}>
          <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 16 }}>
            📍 Ventas por ciudad
          </h3>
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {data.ventas_ciudad.map((c, i) => (
              <div key={i} style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 600 }}>{c.ciudad}</div>
                  <div style={{ fontSize: 11, color: c.crecimiento.startsWith("+") ? C.green : C.red }}>
                    {c.crecimiento.startsWith("+") ? "↗" : "↘"} Crecimiento: {c.crecimiento}
                  </div>
                </div>
                <span style={{ fontSize: 14, fontWeight: 800, color: C.coral }}>
                  Q{c.total.toLocaleString()}
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
            {data.evolucion_mensual.map((m, i) => {
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
