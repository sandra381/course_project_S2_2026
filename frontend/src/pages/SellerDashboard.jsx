import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Button from "../components/Button.jsx";
import { DEMO_SELLER } from "../api/demo.js";

export default function SellerDashboard({ user }) {
  // En producción este dato vendría del API Gateway
  const data = DEMO_SELLER;
  const maxVal = Math.max(...data.evolucion_mensual.map((m) => m.total));

  return (
    <div className="fade-in">
      {/* Header */}
      <div style={{ marginBottom: 24, display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <span style={{ fontSize: 11, fontWeight: 700, color: C.coral, textTransform: "uppercase", letterSpacing: "0.08em", background: C.coralLt, padding: "4px 12px", borderRadius: 20 }}>
            Reporte Mensual
          </span>
          <h1 style={{ fontSize: 22, fontWeight: 800, marginTop: 10 }}>
            Mi Reporte de Ventas — <span style={{ color: C.coral }}>Mayo 2026</span>
          </h1>
          <p style={{ color: C.slateL, fontSize: 12, marginTop: 4 }}>
            Resumen de tu desempeño en el período actual. Analiza tus metas y productos clave.
          </p>
        </div>
        <Button>↓ Descargar PDF</Button>
      </div>

      {/* KPIs */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: 16, marginBottom: 24 }}>
        {[
          { label: "Total Vendido",      value: `Q${data.total_vendido.toLocaleString()}`, delta: data.delta_ventas,    icon: "💰" },
          { label: "Productos Vendidos", value: data.productos_vendidos.toLocaleString(),  delta: data.delta_productos,  icon: "📦" },
          { label: "Clientes Atendidos", value: data.clientes_atendidos,                  delta: data.delta_clientes,   icon: "👥" },
          { label: "Posición Ranking",   value: `#${data.ranking} de ${data.total_vendedores}`, delta: "↑ Subiste 1 posición", icon: "🏆" },
        ].map((m, i) => (
          <Card key={i} style={{ padding: "18px 20px" }}>
            <div style={{ fontSize: 11, color: C.slateL, fontWeight: 600, marginBottom: 6 }}>
              {m.icon} {m.label}
            </div>
            <div style={{ fontSize: 20, fontWeight: 800, color: C.navy }}>{m.value}</div>
            <div style={{ fontSize: 11, color: C.green, marginTop: 4 }}>↗ {m.delta}</div>
          </Card>
        ))}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 }}>
        {/* Tabla de productos */}
        <Card style={{ padding: 20 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h3 style={{ fontWeight: 700, fontSize: 14 }}>🏅 Productos más vendidos</h3>
            <button style={{ fontSize: 12, color: C.coral, background: "none", border: "none", cursor: "pointer", fontWeight: 600 }}>
              Ver todos →
            </button>
          </div>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr>
                {["Producto", "Cantidad", "Total"].map((h) => (
                  <th key={h} style={{ textAlign: "left", fontSize: 10, color: C.slateL, fontWeight: 700, textTransform: "uppercase", padding: "0 0 10px" }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data.productos.map((p, i) => (
                <tr key={i} style={{ borderTop: `1px solid ${C.gray}` }}>
                  <td style={{ padding: "10px 0" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 13 }}>
                      <div style={{ width: 28, height: 28, borderRadius: 6, background: C.coralLt, display: "flex", alignItems: "center", justifyContent: "center" }}>
                        🖥
                      </div>
                      <span style={{ fontWeight: 500 }}>{p.nombre}</span>
                    </div>
                  </td>
                  <td style={{ padding: "10px 0", fontSize: 13, color: C.slateL }}>{p.cantidad}</td>
                  <td style={{ padding: "10px 0", fontSize: 13, fontWeight: 700, color: C.coral }}>
                    Q{p.total.toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>

        {/* Gráfico de evolución mensual */}
        <Card style={{ padding: 20 }}>
          <h3 style={{ fontWeight: 700, fontSize: 14, marginBottom: 24 }}>📈 Evolución Mensual</h3>
          <div style={{ display: "flex", alignItems: "flex-end", gap: 16, height: 140 }}>
            {data.evolucion_mensual.map((m, i) => {
              const isLast = i === data.evolucion_mensual.length - 1;
              const barH   = Math.round((m.total / maxVal) * 120);
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

      {/* Aviso de acceso restringido */}
      <div style={{ marginTop: 16, padding: "12px 16px", borderRadius: 10, background: C.amberLt, fontSize: 12, color: C.amber, fontWeight: 500 }}>
        ⚠️ Solo tienes acceso a tu propio desempeño. Los datos de otros vendedores no son visibles.
      </div>
    </div>
  );
}
