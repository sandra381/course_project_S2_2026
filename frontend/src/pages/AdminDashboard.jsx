import { useState, useEffect } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Button from "../components/Button.jsx";
import Spinner from "../components/Spinner.jsx";
import { IS_DEMO } from "../api/client.js";
import { DEMO_ERRORS } from "../api/demo.js";

const DEMO_STATS = {
  total_trabajos: 1284,
  trabajos_hoy: 24,
  errores_hoy: 12,
  errores_pendientes: 5,
  usuarios_activos: 18,
  tiempo_promedio: "2.5 min",
};

export default function AdminDashboard({ setPage }) {
  const [stats, setStats]         = useState(DEMO_STATS);
  const [errores, setErrores]     = useState([]);
  const [loading, setLoading]     = useState(true);

  useEffect(() => {
    const load = async () => {
      await new Promise((r) => setTimeout(r, 400));
      setErrores(DEMO_ERRORS.slice(0, 3)); // últimos 3 errores
      setLoading(false);
    };
    load();
  }, []);

  return (
    <div className="fade-in">
      {/* Header */}
      <div style={{ marginBottom: 28 }}>
        <h1 style={{ fontSize: 22, fontWeight: 800 }}>Panel de Administración</h1>
        <p style={{ color: C.slateL, fontSize: 13, marginTop: 4 }}>
          Monitoreo general del sistema y estado de errores.
        </p>
      </div>

      {/* Métricas del sistema */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 16, marginBottom: 28 }}>
        {[
          { label: "Total Trabajos Procesados", value: stats.total_trabajos.toLocaleString(), delta: `+${stats.trabajos_hoy} hoy`, icon: "📊", color: C.coral },
          { label: "Errores Hoy",               value: stats.errores_hoy,                     delta: `${stats.errores_pendientes} sin revisar`, icon: "⚠️", color: C.red   },
          { label: "Usuarios Activos",           value: stats.usuarios_activos,                delta: "En el sistema",           icon: "👥", color: C.blue  },
        ].map((m, i) => (
          <Card key={i} style={{ padding: "20px 24px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div>
              <div style={{ fontSize: 12, color: C.slateL, fontWeight: 600, marginBottom: 4 }}>{m.label}</div>
              <div style={{ fontSize: 32, fontWeight: 800, color: m.color }}>{m.value}</div>
              <div style={{ fontSize: 11, color: C.slateL, marginTop: 4 }}>{m.delta}</div>
            </div>
            <span style={{ fontSize: 30 }}>{m.icon}</span>
          </Card>
        ))}
      </div>

      {/* Últimos errores */}
      <Card>
        <div style={{ padding: "18px 24px 14px", display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: `1px solid ${C.gray}` }}>
          <div>
            <h2 style={{ fontSize: 16, fontWeight: 700 }}>Errores recientes</h2>
            <p style={{ fontSize: 12, color: C.slateL, marginTop: 2 }}>
              Últimos incidentes registrados en el sistema.
            </p>
          </div>
          <Button variant="outline" size="sm" onClick={() => setPage("errors")}>
            Ver todos los errores →
          </Button>
        </div>

        {loading ? (
          <div style={{ padding: 48, display: "flex", justifyContent: "center" }}><Spinner /></div>
        ) : (
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ background: C.grayLt }}>
                {["ID Error", "ID Trabajo", "Usuario", "Fecha", "Descripción"].map((h) => (
                  <th key={h} style={{ padding: "10px 20px", textAlign: "left", fontSize: 11, fontWeight: 700, color: C.slateL, textTransform: "uppercase", letterSpacing: "0.05em" }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {errores.map((e) => (
                <tr
                  key={e.id}
                  style={{ borderTop: `1px solid ${C.gray}` }}
                  onMouseEnter={(ev) => (ev.currentTarget.style.background = C.grayLt)}
                  onMouseLeave={(ev) => (ev.currentTarget.style.background = "transparent")}
                >
                  <td style={{ padding: "14px 20px" }}>
                    <span style={{ fontFamily: "'JetBrains Mono',monospace", fontSize: 11, color: C.red, fontWeight: 600 }}>
                      #{e.id}
                    </span>
                  </td>
                  <td style={{ padding: "14px 20px" }}>
                    <span style={{ fontFamily: "'JetBrains Mono',monospace", fontSize: 11, fontWeight: 600 }}>
                      {e.job_id}
                    </span>
                  </td>
                  <td style={{ padding: "14px 20px" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <div style={{ width: 28, height: 28, borderRadius: "50%", background: C.coral, display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", fontSize: 11, fontWeight: 700, flexShrink: 0 }}>
                        {e.usuario.charAt(0)}
                      </div>
                      <span style={{ fontSize: 13, fontWeight: 500 }}>{e.usuario}</span>
                    </div>
                  </td>
                  <td style={{ padding: "14px 20px", fontSize: 12, color: C.slateL }}>
                    {new Date(e.fecha).toLocaleString("es-GT", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })}
                  </td>
                  <td style={{ padding: "14px 20px" }}>
                    <div style={{ display: "flex", alignItems: "flex-start", gap: 8 }}>
                      <span style={{ color: C.red, flexShrink: 0 }}>⚠️</span>
                      <span style={{ fontSize: 12, color: C.slate, lineHeight: 1.5 }}>
                        {e.descripcion}
                      </span>
                    </div>
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
