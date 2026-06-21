import { useState, useEffect } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Spinner from "../components/Spinner.jsx";
import { getSellerHistory, IS_DEMO } from "../api/client.js";
import { DEMO_REPORTS } from "../api/demo.js";

export default function SellerHistory({ user }) {
  const [reportes, setReportes] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [search, setSearch]     = useState("");

  useEffect(() => {
    const load = async () => {
      try {
        if (IS_DEMO) {
          await new Promise((r) => setTimeout(r, 400));
          setReportes(DEMO_REPORTS);
        } else {
          const data = await getSellerHistory(user.nombre);
          setReportes(data.reportes || []);
        }
      } catch (_) {
        setReportes([]);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [user]);

  const filtered = reportes.filter(
    (r) => !search || (r.periodo || "").toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="fade-in">
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 800 }}>Mi Historial</h1>
        <p style={{ color: C.slateL, fontSize: 13, marginTop: 4 }}>
          Tus reportes de desempeño generados en cada período procesado.
        </p>
      </div>

      <Card>
        <div style={{ padding: "16px 20px", borderBottom: `1px solid ${C.gray}` }}>
          <div style={{ position: "relative", maxWidth: 320 }}>
            <span style={{ position: "absolute", left: 12, top: "50%", transform: "translateY(-50%)", color: C.slateL }}>🔍</span>
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Buscar por período..."
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
                {["Período", "Total Vendido", "Productos", "Clientes", "Fecha"].map((h) => (
                  <th key={h} style={{ padding: "10px 20px", textAlign: "left", fontSize: 11, fontWeight: 700, color: C.slateL, textTransform: "uppercase", letterSpacing: "0.05em" }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={5} style={{ padding: 32, textAlign: "center", color: C.slateL, fontSize: 13 }}>
                    Todavía no tenés reportes generados.
                  </td>
                </tr>
              ) : filtered.map((r) => (
                <tr
                  key={r.id_reporte_vendedor || r.id}
                  style={{ borderTop: `1px solid ${C.gray}` }}
                  onMouseEnter={(e) => (e.currentTarget.style.background = C.grayLt)}
                  onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
                >
                  <td style={{ padding: "14px 20px", fontSize: 13, fontWeight: 600 }}>{r.periodo}</td>
                  <td style={{ padding: "14px 20px", fontSize: 13, fontWeight: 700, color: C.coral }}>
                    Q{Number(r.total_vendido).toLocaleString()}
                  </td>
                  <td style={{ padding: "14px 20px", fontSize: 13, color: C.slateL }}>
                    {r.productos_vendidos}
                  </td>
                  <td style={{ padding: "14px 20px", fontSize: 13, color: C.slateL }}>
                    {r.clientes_atendidos}
                  </td>
                  <td style={{ padding: "14px 20px", fontSize: 12, color: C.slateL }}>
                    {new Date(r.fecha_generado).toLocaleDateString("es-GT")}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}