import { useState, useEffect } from "react";
import { C } from "../styles.js";
import Card from "../components/Card.jsx";
import Spinner from "../components/Spinner.jsx";
import { getJob, IS_DEMO } from "../api/client.js";

const STEPS = [
  { key: "recibido",     label: "Archivo recibido",    sub: "CSV cargado exitosamente"          },
  { key: "validacion",   label: "Validación del CSV",  sub: "Estructura y tipos de datos"       },
  { key: "procesando",   label: "Procesando datos",    sub: "Cálculo de ventas y rankings"      },
  { key: "generando",    label: "Generando PDF",       sub: "Creando reportes visuales"         },
  { key: "notificacion", label: "Notificación enviada",sub: "Envío por correo a responsables"   },
];

const DEMO_LOGS = [
  { time: "14:20:05", msg: "Iniciando generación de reporte PDF general." },
  { time: "14:20:12", msg: "Procesando ranking de productos más vendidos." },
  { time: "14:20:30", msg: "Calculando métricas por vendedor." },
  { time: "14:20:45", msg: "Generando gráficos de análisis mensual." },
  { time: "14:21:02", msg: "Ensamblando páginas del documento final." },
];

function estadoAProgreso(estado) {
  switch (estado) {
    case "PENDIENTE":  return { step: 1, progress: 20 };
    case "PROCESANDO": return { step: 2, progress: 60 };
    case "COMPLETADO": return { step: 5, progress: 100 };
    case "FALLIDO":    return { step: 2, progress: 100 };
    default:           return { step: 0, progress: 5 };
  }
}

export default function JobStatus({ job }) {
  const [currentStep, setCurrentStep] = useState(0);
  const [progress, setProgress]       = useState(5);
  const [logs, setLogs]               = useState(DEMO_LOGS.slice(0, 1));
  const [jobData, setJobData]         = useState(job);

  useEffect(() => {
    if (!job || !job.job_id || IS_DEMO) return;

    let activo = true;

    const consultar = async () => {
      try {
        const data = await getJob(job.job_id);
        if (!activo) return;
        setJobData(data);

        const { step, progress: pct } = estadoAProgreso(data.estado);
        setCurrentStep(step);
        setProgress(pct);

        if (data.estado === "COMPLETADO" || data.estado === "FALLIDO") {
          clearInterval(interval);
        }
      } catch (_) {}
    };

    consultar();
    const interval = setInterval(consultar, 3000);

    return () => {
      activo = false;
      clearInterval(interval);
    };
  }, [job?.job_id]);

  useEffect(() => {
    if (!job || !IS_DEMO) return;
    const timer = setInterval(() => {
      setProgress((p) => {
        if (p >= 100) { clearInterval(timer); return 100; }
        return p + 1.5;
      });
      setCurrentStep((s) => (s < 4 && Math.random() > 0.93 ? s + 1 : s));
      setLogs((prev) => {
        const next = DEMO_LOGS[prev.length];
        return next ? [...prev, next] : prev;
      });
    }, 350);
    return () => clearInterval(timer);
  }, [job]);

  if (!job) {
    return (
      <div style={{ textAlign: "center", padding: 64, color: C.slateL }}>
        <div style={{ fontSize: 40, marginBottom: 12 }}>📋</div>
        <div style={{ fontWeight: 600, color: C.slate }}>Sin trabajo seleccionado</div>
        <div style={{ fontSize: 13, marginTop: 4 }}>Sube un CSV para ver el estado aquí.</div>
      </div>
    );
  }

  return (
    <div className="fade-in">
      <div style={{ marginBottom: 24 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 4 }}>
          <h1 style={{ fontSize: 20, fontWeight: 800 }}>Estado del trabajo</h1>
          <span style={{ fontFamily: "'JetBrains Mono',monospace", fontSize: 14, color: C.coral, fontWeight: 700 }}>
            #{job.job_id}
          </span>
        </div>
        <p style={{ fontSize: 13, color: C.slateL }}>
          Monitoreando el procesamiento de: <strong>{job.nombre_archivo}</strong>
        </p>
      </div>

      <Card style={{ padding: 28, marginBottom: 20 }}>
        <div style={{ display: "flex", justifyContent: "space-between", position: "relative", marginBottom: 32 }}>
          <div style={{ position: "absolute", top: 19, left: "5%", right: "5%", height: 2, background: C.gray, zIndex: 0 }} />

          {STEPS.map((step, i) => {
            const done   = i < currentStep;
            const active = i === currentStep;
            return (
              <div key={step.key} style={{ display: "flex", flexDirection: "column", alignItems: "center", zIndex: 1, flex: 1 }}>
                <div
                  className={active ? "pulse" : undefined}
                  style={{
                    width: 40, height: 40, borderRadius: "50%",
                    background: done ? C.green : active ? C.coral : C.gray,
                    display: "flex", alignItems: "center", justifyContent: "center",
                    color: "#fff", fontSize: 14, fontWeight: 700, marginBottom: 8,
                  }}
                >
                  {done ? "✓" : active ? <Spinner size={16} /> : i + 1}
                </div>
                <div style={{ fontSize: 11, fontWeight: 600, textAlign: "center", color: done || active ? C.navy : C.slateL }}>
                  {step.label}
                </div>
                <div style={{ fontSize: 10, color: C.slateL, textAlign: "center" }}>
                  {step.sub}
                </div>
              </div>
            );
          })}
        </div>

        <div>
          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8 }}>
            <span style={{ fontSize: 13, fontWeight: 600, color: C.slate }}>Progreso General</span>
            <span style={{ fontSize: 14, fontWeight: 800, color: C.coral }}>{Math.round(progress)}%</span>
          </div>
          <div style={{ height: 8, background: C.gray, borderRadius: 4, overflow: "hidden" }}>
            <div
              style={{
                height: "100%",
                width: `${progress}%`,
                background: jobData?.estado === "FALLIDO"
                  ? C.red
                  : `linear-gradient(to right, ${C.coral}, ${C.coralDk})`,
                borderRadius: 4,
                transition: "width 0.4s ease",
              }}
            />
          </div>
          {jobData?.estado === "FALLIDO" ? (
            <p style={{ fontSize: 12, color: C.red, marginTop: 6, fontWeight: 600 }}>
              El procesamiento falló. Revisá el registro de errores.
            </p>
          ) : progress < 100 ? (
            <p style={{ fontSize: 12, color: C.slateL, marginTop: 6 }}>
              Generando reporte PDF y reportes individuales por vendedor.
            </p>
          ) : (
            <p style={{ fontSize: 12, color: C.green, marginTop: 6, fontWeight: 600 }}>
              ✅ Reporte generado exitosamente.
            </p>
          )}
        </div>
      </Card>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 }}>
        <Card style={{ padding: 20 }}>
          <h3 style={{ fontSize: 13, fontWeight: 700, color: C.slate, marginBottom: 14, textTransform: "uppercase", letterSpacing: "0.05em" }}>
            📋 Registro de Actividad
          </h3>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {IS_DEMO ? (
              logs.map((log, i) => (
                <div key={i} style={{ display: "flex", gap: 10, fontSize: 12 }}>
                  <span style={{ fontFamily: "'JetBrains Mono',monospace", color: C.coral, flexShrink: 0 }}>{log.time}</span>
                  <span style={{ color: C.slate }}>{log.msg}</span>
                </div>
              ))
            ) : (
              <div style={{ fontSize: 12, color: C.slateL }}>
                Estado actual: <strong>{jobData?.estado || "Consultando..."}</strong>
              </div>
            )}
          </div>
        </Card>

        <Card style={{ padding: 20 }}>
          <h3 style={{ fontSize: 13, fontWeight: 700, color: C.slate, marginBottom: 14, textTransform: "uppercase", letterSpacing: "0.05em" }}>
            ℹ️ Detalles del trabajo
          </h3>
          <div style={{ display: "flex", flexDirection: "column", gap: 12, fontSize: 13 }}>
            {[
              { label: "🕐 Inicio",    value: new Date(job.fecha_carga).toLocaleString("es-GT") },
              { label: "⏱ Estado",    value: jobData?.estado || "PENDIENTE" },
              { label: "📄 Archivo",   value: job.nombre_archivo },
              { label: "🆔 Job ID",    value: job.job_id, mono: true },
            ].map((row) => (
              <div key={row.label} style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <span style={{ color: C.slateL }}>{row.label}</span>
                <span style={{
                  fontWeight: 600,
                  fontFamily: row.mono ? "'JetBrains Mono',monospace" : undefined,
                  fontSize: row.mono ? 12 : 13,
                  maxWidth: 180, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
                }}>
                  {row.value}
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}