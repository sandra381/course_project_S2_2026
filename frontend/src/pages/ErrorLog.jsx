import { useState, useEffect } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Spinner from "../components/Spinner.jsx";
import Button from "../components/Button.jsx";
import { getErrors, IS_DEMO } from "../api/client.js";
import { DEMO_ERRORS } from "../api/demo.js";

export default function ErrorLog() {
  const [errors, setErrors]   = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch]   = useState("");

  useEffect(() => {
    const load = async () => {
      try {
        if (IS_DEMO) {
          await new Promise((r) => setTimeout(r, 400));
          setErrors(DEMO_ERRORS);
        } else {
          const data = await getErrors();
          setErrors(data.errors);
        }
      } catch (_) {
        setErrors(DEMO_ERRORS);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const filtered = errors.filter(
    (e) =>
      !search ||
      e.job_id.toLowerCase().includes(search.toLowerCase()) ||
      e.usuario.toLowerCase().includes(search.toLowerCase()) ||
      e.descripcion.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="fade-in">
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 800 }}>Registro de Errores</h1>
        <p style={{ color: C.slateL, fontSize: 13, marginTop: 4 }}>
          Monitorea y diagnostica fallos en el procesamiento de ventas y generación de reportes.
        </p>
      </div>

      {/* Totales */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(2,1fr)", gap: 16, marginBottom: 24, maxWidth: 480 }}>
        {[
          { label: "Errores Hoy", value: 12, delta: "+4 desde ayer",       color: C.red   },
          { label: "Pendientes",  value: 5,  delta: "Errores sin revisar", color: C.amber },
        ].map((m, i) => (
          <Card key={i} style={{ padding: "16px 20px" }}>
            <div style={{ fontSize: 11, color: C.slateL, fontWeight: 600 }}>{m.label}</div>
            <div style={{ fontSize: 28, fontWeight: 800, color: m.color }}>{m.value}</div>
            <div style={{ fontSize: 11, color: C.slateL, marginTop: 2 }}>{m.delta}</div>
          </Card>
        ))}
      </div>

      <Card>
        {/* Header con búsqueda */}
        <div style={{ padding: "16px 20px", borderBottom: `1px solid ${C.gray}`, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div>
            <div style={{ fontWeight: 700, fontSize: 14 }}>Incidentes Recientes</div>
            <div style={{ fontSize: 11, color: C.slateL }}>Últimos 50 errores detectados</div>
          </div>
          <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
            <div style={{ position: "relative" }}>
              <span style={{ position: "absolute", left: 10, top: "50%", transform: "translateY(-50%)", color: C.slateL, fontSize: 14 }}>🔍</span>
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Buscar por ID de trabajo o usuario..."
                style={{ padding: "7px 14px 7px 32px", borderRadius: 8, border: `1.5px solid ${C.gray}`, fontSize: 12, width: 300, outline: "none" }}
              />
            </div>
            <Button variant="navy" size="sm">▼ Filtrar</Button>
          </div>
        </div>

        {/* Tabla */}
        {loading ? (
          <div style={{ padding: 48, display: "flex", justifyContent: "center" }}><Spinner /></div>
        ) : (
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ background: C.grayLt }}>
                {["ID Error", "ID Trabajo", "Usuario", "Fecha y Hora", "Descripción del Error"].map((h) => (
                  <th key={h} style={{ padding: "10px 16px", textAlign: "left", fontSize: 11, fontWeight: 700, color: C.slateL, textTransform: "uppercase", letterSpacing: "0.04em" }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((e) => (
                <tr
                  key={e.id}
                  style={{ borderTop: `1px solid ${C.gray}` }}
                  onMouseEnter={(ev) => (ev.currentTarget.style.background = C.grayLt)}
                  onMouseLeave={(ev) => (ev.currentTarget.style.background = "transparent")}
                >
                  <td style={{ padding: "14px 16px" }}>
                    <span style={{ fontFamily: "'JetBrains Mono',monospace", fontSize: 11, color: C.red, fontWeight: 600 }}>
                      #{e.id}
                    </span>
                  </td>
                  <td style={{ padding: "14px 16px" }}>
                    <span style={{ fontFamily: "'JetBrains Mono',monospace", fontSize: 11, fontWeight: 600 }}>
                      {e.job_id}
                    </span>
                  </td>
                  <td style={{ padding: "14px 16px" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <div style={{ width: 28, height: 28, borderRadius: "50%", background: C.coral, display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", fontSize: 11, fontWeight: 700, flexShrink: 0 }}>
                        {e.usuario.charAt(0)}
                      </div>
                      <div>
                        <div style={{ fontSize: 12, fontWeight: 600 }}>{e.usuario}</div>
                        <div style={{ fontSize: 10, color: C.slateL }}>{e.rol}</div>
                      </div>
                    </div>
                  </td>
                  <td style={{ padding: "14px 16px", fontSize: 12, color: C.slateL }}>
                    {new Date(e.fecha).toLocaleString("es-GT")}
                  </td>
                  <td style={{ padding: "14px 16px" }}>
                    <div style={{ display: "flex", alignItems: "flex-start", gap: 8 }}>
                      <span style={{ color: C.red, flexShrink: 0, marginTop: 1 }}>⚠️</span>
                      <span style={{ fontSize: 12, color: C.slate, lineHeight: 1.5 }}>{e.descripcion}</span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        {/* Paginación */}
        <div style={{ padding: "14px 20px", borderTop: `1px solid ${C.gray}`, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ fontSize: 12, color: C.slateL }}>Mostrando 1 a {filtered.length} de 124 errores</span>
          <div style={{ display: "flex", gap: 4 }}>
            <button style={{ padding: "5px 12px", borderRadius: 6, border: `1.5px solid ${C.gray}`, background: "transparent", color: C.slateL, fontSize: 12, cursor: "pointer" }}>← Anterior</button>
            {[1, 2, 3].map((p) => (
              <button key={p} style={{ width: 30, height: 30, borderRadius: 6, border: `1.5px solid ${p === 1 ? C.coral : C.gray}`, background: p === 1 ? C.coral : "transparent", color: p === 1 ? "#fff" : C.slateL, fontSize: 12, fontWeight: 600, cursor: "pointer" }}>
                {p}
              </button>
            ))}
            <button style={{ padding: "5px 12px", borderRadius: 6, border: `1.5px solid ${C.coral}`, background: "transparent", color: C.coral, fontSize: 12, fontWeight: 600, cursor: "pointer" }}>Siguiente →</button>
          </div>
        </div>
      </Card>
    </div>
  );
}
