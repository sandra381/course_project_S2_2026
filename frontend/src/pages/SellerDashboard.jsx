import { useState, useEffect } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Button from "../components/Button.jsx";
import Spinner from "../components/Spinner.jsx";
import { getSellerDashboard, IS_DEMO } from "../api/client.js";
import { DEMO_SELLER } from "../api/demo.js";

export default function SellerDashboard({ user }) {
  const [data, setData]       = useState(IS_DEMO ? DEMO_SELLER : null);
  const [loading, setLoading] = useState(!IS_DEMO);
  const [error, setError]     = useState("");

  useEffect(() => {
    if (IS_DEMO) return;
    const load = async () => {
      try {
        // El backend identifica al vendedor por su NOMBRE (coincide con
        // la columna salesperson_name del CSV), no por id_usuario.
        const result = await getSellerDashboard(user.nombre);
        setData(result);
      } catch (e) {
        setError("No se pudieron cargar tus métricas todavía.");
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [user]);

  if (loading) {
    return (
      <div style={{ padding: 64, display: "flex", justifyContent: "center" }}>
        <Spinner />
      </div>
    );
  }

  if (error || !data) {
    return (
      <div style={{ textAlign: "center", padding: 64, color: C.slateL }}>
        <div style={{ fontSize: 40, marginBottom: 12 }}>📊</div>
        <div style={{ fontWeight: 600, color: C.slate }}>
          {error || "Todavía no tenés ventas registradas."}
        </div>
        <div style={{ fontSize: 13, marginTop: 4 }}>
          En cuanto se procese un CSV con tus ventas, vas a ver tus métricas aquí.
        </div>
      </div>
    );
  }

  const evolucion = data.evolucion_mensual || [];
  const maxVal = evolucion.length ? Math.max(...evolucion.map((m) => m.total)) : 1;
  const productos = data.top_productos || [];

  return (
    <div className="fade-in">
      <div style={{ marginBottom: 24, display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <span style={{ fontSize: 11, fontWeight: 700, color: C.coral, textTransform: "uppercase", letterSpacing: "0.08em", background: C.coralLt, padding: "4px 12px", borderRadius: 20 }}>
            Mi Desempeño
          </span>
          <h1 style={{ fontSize: 22, fontWeight: 800, marginTop: 10 }}>
            Hola, <span style={{ color: C.coral }}>{user.nombre.split(" ")[0]}</span> 👋
          </h1>
          <p style={{ color: C.slateL, fontSize: 12, marginTop: 4 }}>
            Resumen acumulado de tu desempeño en todos los períodos procesados.
          </p>
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: 16, marginBottom: 24 }}>
        {[
          { label: "Total Vendido",      value: `Q${Number(data.total_vendido).toLocaleString()}`, icon: "💰" },
          { label: "Productos Vendidos", value: Number(data.productos_vendidos).toLocaleString(),  icon: "📦" },
          { label: "Clientes Atendidos", value: data.clientes_atendidos,                            icon: "👥" },
          { label: "Posición Ranking",   value: data.ranking_total ? `#${data.ranking_posicion} de ${data.ranking_total}` : "—", icon: "🏆" },
        ].map((m, i) => (
          <Card key={i} style={{ padding: "18px 20px" }}>
            <div style={{ fontSize: 11, color: C.slateL, fontWeight: 600, marginBottom: 6 }}>
              {m.icon} {m.label}
            </div>
            <div style={{ fontSize: 20, fontWeight: 800, color: C.navy }}>{m.value}</div>
          </Card>
        ))}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 }}>
        <Card style={{ padding: 20 }}>
          <h3 style={{ fontWeight: 700, fontSize: 14, marginBottom: 16 }}>🏅 Productos más vendidos</h3>
          {productos.length === 0 ? (
            <div style={{ fontSize: 12, color: C.slateL }}>Sin datos todavía.</div>
          ) : (
            <table style={{ width: "100%", borderCollapse: "collapse" }}>
              <thead>
                <tr>
                  {["Producto", "Total"].map((h) => (
                    <th key={h} style={{ textAlign: "left", fontSize: 10, color: C.slateL, fontWeight: 700, textTransform: "uppercase", padding: "0 0 10px" }}>
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {productos.map((p, i) => (
                  <tr key={i} style={{ borderTop: `1px solid ${C.gray}` }}>
                    <td style={{ padding: "10px 0" }}>
                      <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 13 }}>
                        <div style={{ width: 28, height: 28, borderRadius: 6, background: C.coralLt, display: "flex", alignItems: "center", justifyContent: "center" }}>
                          🖥
                        </div>
                        <span style={{ fontWeight: 500 }}>{p.nombre}</span>
                      </div>
                    </td>
                    <td style={{ padding: "10px 0", fontSize: 13, fontWeight: 700, color: C.coral }}>
                      Q{Number(p.total).toLocaleString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Card>

        <Card style={{ padding: 20 }}>
          <h3 style={{ fontWeight: 700, fontSize: 14, marginBottom: 24 }}>📈 Evolución Mensual</h3>
          {evolucion.length === 0 ? (
            <div style={{ fontSize: 12, color: C.slateL }}>Sin datos todavía.</div>
          ) : (
            <div style={{ display: "flex", alignItems: "flex-end", gap: 16, height: 140 }}>
              {evolucion.map((m, i) => {
                const isLast = i === evolucion.length - 1;
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
          )}
        </Card>
      </div>
    </div>
  );
}
