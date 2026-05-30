import { C } from "../styles.js";

// Menú por rol — cada rol ve solo sus pantallas
const NAV_BY_ROL = {
  analista: [
    { id: "dashboard", label: "Dashboard",       icon: "⊞" },
    { id: "upload",    label: "Cargar CSV",       icon: "↑" },
    { id: "history",   label: "Historial",        icon: "🕐" },
  ],
  gerente: [
    { id: "history",   label: "Historial",        icon: "🕐" },
  ],
  vendedor: [
    { id: "seller",    label: "Mi Desempeño",     icon: "📊" },
  ],
  administrador: [
    { id: "dashboard", label: "Dashboard",        icon: "⊞" },
    { id: "errors",    label: "Registro Errores", icon: "⚠️" },
  ],
  auditor: [
    { id: "history",   label: "Todos los Reportes", icon: "🕐" },
  ],
};

export default function Sidebar({ user, page, setPage, onLogout }) {
  const nav = NAV_BY_ROL[user.rol] || [];

  return (
    <aside
      style={{
        width: 220,
        minHeight: "100vh",
        background: C.navy,
        display: "flex",
        flexDirection: "column",
        position: "fixed",
        left: 0,
        top: 0,
        zIndex: 100,
      }}
    >
      {/* Logo */}
      <div style={{ padding: "24px 20px 20px", borderBottom: `1px solid ${C.navyLt}` }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div
            style={{
              width: 36, height: 36, borderRadius: 10,
              background: C.coral,
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 16, fontWeight: 800, color: "#fff",
            }}
          >
            S
          </div>
          <div>
            <div style={{ fontWeight: 800, color: "#fff", fontSize: 15, letterSpacing: "0.03em" }}>SPVR</div>
            <div style={{ fontSize: 10, color: C.slateL }}>v1.0.0</div>
          </div>
        </div>
      </div>

      {/* Navegación */}
      <nav style={{ flex: 1, padding: "16px 12px" }}>
        {nav.map((item) => {
          const active = page === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setPage(item.id)}
              style={{
                width: "100%",
                display: "flex",
                alignItems: "center",
                gap: 10,
                padding: "10px 12px",
                borderRadius: 10,
                marginBottom: 2,
                background: active ? C.coral : "transparent",
                color: active ? "#fff" : C.slateL,
                fontSize: 13,
                fontWeight: 600,
                border: "none",
                cursor: "pointer",
                transition: "all 0.15s",
                textAlign: "left",
              }}
            >
              <span style={{ fontSize: 15 }}>{item.icon}</span>
              {item.label}
            </button>
          );
        })}
      </nav>

      {/* Usuario y logout */}
      <div style={{ padding: "16px 20px", borderTop: `1px solid ${C.navyLt}` }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 12 }}>
          <div
            style={{
              width: 36, height: 36, borderRadius: "50%",
              background: C.coral, flexShrink: 0,
              display: "flex", alignItems: "center", justifyContent: "center",
              fontWeight: 700, color: "#fff", fontSize: 14,
            }}
          >
            {user.nombre?.charAt(0)}
          </div>
          <div style={{ overflow: "hidden" }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: "#fff", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
              {user.nombre}
            </div>
            <div style={{ fontSize: 11, color: C.slateL, textTransform: "capitalize" }}>
              {user.rol}
            </div>
          </div>
        </div>

        <button
          onClick={onLogout}
          style={{
            width: "100%",
            padding: "8px",
            borderRadius: 8,
            background: C.navyLt,
            color: C.slateL,
            fontSize: 12,
            fontWeight: 600,
            border: "none",
            cursor: "pointer",
          }}
        >
          Cerrar sesión
        </button>
      </div>
    </aside>
  );
}
