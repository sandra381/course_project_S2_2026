import { useState, useEffect } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Spinner from "../components/Spinner.jsx";
import { getErrors, IS_DEMO } from "../api/client.js";
import { DEMO_ERRORS } from "../api/demo.js";
import { parseUTC } from "../api/client.js";  // agregar al import existente

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
          setErrors(data.errors || []);
        }
      } catch (_) {
        setErrors(IS_DEMO ? DEMO_ERRORS : []);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  // El backend (GET /errors) hace JOIN con usuarios y devuelve:
  // id_error, job_id, id_usuario, fecha, descripcion, nombre, email
  // (no devuelve "id" ni "usuario" ni "rol" — por eso usamos nombre/email aquí)
  const filtered = errors.filter((e) => {
    const usuario = e.usuario || e.nombre || "";
    const jobId    = String(e.job_id || "");
    return (
      !search ||
      jobId.toLowerCase().includes(search.toLowerCase()) ||
      usuario.toLowerCase().includes(search.toLowerCase()) ||
      (e.descripcion || "").toLowerCase().includes(search.toLowerCase())
    );
  });

  return (
    <div className="fade-in">
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 800 }}>Registro de Errores</h1>
        <p style={{ color: C.slateL, fontSize: 13, marginTop: 4 }}>
          Monitorea y diagnostica fallos en el procesamiento de ventas y generación de reportes.
        </p>
      </div>

      <Card>
        <div style={{ padding: "16px 20px", borderBottom: `1px solid ${C.gray}`, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div>
            <div style={{ fontWeight: 700, fontSize: 14 }}>Incidentes Recientes</div>
            <div style={{ fontSize: 11, color: C.slateL }}>{errors.length} errores detectados</div>
          </div>
          <div style={{ position: "relative" }}>
            <span style={{ position: "absolute", left: 10, top: "50%", transform: "translateY(-50%)", color: C.slateL, fontSize: 14 }}>🔍</span>
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Buscar por ID de trabajo o usuario..."
              style={{ padding: "7px 14px 7px 32px", borderRadius: 8, border: `1.5px solid ${C.gray}`, fontSize: 12, width: 300, outline: "none" }}
            />
          </div>
        </div>

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
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={5} style={{ padding: 32, textAlign: "center", color: C.slateL, fontSize: 13 }}>
                    Sin errores registrados.
                  </td>
                </tr>
              ) : filtered.map((e) => {
                const usuario = e.usuario || e.nombre || "Desconocido";
                const errorId = e.id || e.id_error;
                return (
                  <tr
                    key={errorId}
                    style={{ borderTop: `1px solid ${C.gray}` }}
                    onMouseEnter={(ev) => (ev.currentTarget.style.background = C.grayLt)}
                    onMouseLeave={(ev) => (ev.currentTarget.style.background = "transparent")}
                  >
                    <td style={{ padding: "14px 16px" }}>
                      <span style={{ fontFamily: "'JetBrains Mono',monospace", fontSize: 11, color: C.red, fontWeight: 600 }}>
                        #{errorId}
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
                          {usuario.charAt(0)}
                        </div>
                        <div>
                          <div style={{ fontSize: 12, fontWeight: 600 }}>{usuario}</div>
                          {e.rol && <div style={{ fontSize: 10, color: C.slateL }}>{e.rol}</div>}
                        </div>
                      </div>
                    </td>
                    <td style={{ padding: "14px 16px", fontSize: 12, color: C.slateL }}>
                      {parseUTC(e.fecha).toLocaleString("es-GT", { timeZone: "America/Guatemala" })}
                    </td>
                    <td style={{ padding: "14px 16px" }}>
                      <div style={{ display: "flex", alignItems: "flex-start", gap: 8 }}>
                        <span style={{ color: C.red, flexShrink: 0, marginTop: 1 }}>⚠️</span>
                        <span style={{ fontSize: 12, color: C.slate, lineHeight: 1.5 }}>{e.descripcion}</span>
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