import { useState } from "react";
import { C } from "../styles.js";
import Button from "../components/Button.jsx";
import Input from "../components/Input.jsx";
import Card from "../components/Card.jsx";
import Spinner from "../components/Spinner.jsx";
import { login, IS_DEMO } from "../api/client.js";
import { DEMO_USERS, DEMO_PASSWORD } from "../api/demo.js";

export default function Login({ onLogin }) {
  const [email, setEmail]       = useState("");
  const [password, setPassword] = useState("");
  const [showPass, setShowPass] = useState(false);
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState("");

  const handleSubmit = async () => {
    if (!email || !password) {
      setError("Ingresa tu correo y contraseña.");
      return;
    }
    setLoading(true);
    setError("");

    try {
      let user;

      if (IS_DEMO) {
        // Modo demo: valida contra los usuarios locales
        await new Promise((r) => setTimeout(r, 700)); // simula latencia
        const found = DEMO_USERS[email.toLowerCase()];
        if (!found || password !== DEMO_PASSWORD) {
          throw new Error("Correo o contraseña incorrectos.");
        }
        user = found;
      } else {
        // Modo real: llama al API Gateway
        const data = await login(email, password);
        user = data.user;
        localStorage.setItem("spvr_token", data.token);
      }

      localStorage.setItem("spvr_user", JSON.stringify(user));
      onLogin(user);
    } catch (e) {
      setError(e.message || "Error al iniciar sesión.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: `linear-gradient(135deg, ${C.navy} 0%, ${C.navyLt} 100%)`,
        padding: 24,
      }}
    >
      <Card style={{ width: "100%", maxWidth: 440, padding: 40 }} className="fade-in">
        {/* Logo */}
        <div style={{ textAlign: "center", marginBottom: 32 }}>
          <div
            style={{
              width: 56, height: 56, borderRadius: 16,
              background: C.coral,
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 24, fontWeight: 800, color: "#fff",
              margin: "0 auto 14px",
            }}
          >
            S
          </div>
          <div style={{ fontWeight: 800, fontSize: 22 }}>Iniciar Sesión</div>
          <div style={{ fontSize: 13, color: C.slateL, marginTop: 4 }}>
            Accede al Sistema de Procesamiento de Ventas y Reportes
          </div>
        </div>

        {/* Formulario */}
        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <Input
            label="Correo electrónico"
            type="email"
            value={email}
            onChange={setEmail}
            placeholder="ejemplo@empresa.com"
            icon="✉"
          />

          <Input
            label="Contraseña"
            type={showPass ? "text" : "password"}
            value={password}
            onChange={setPassword}
            placeholder="••••••••"
            icon="🔒"
            rightElement={
              <button
                onClick={() => setShowPass(!showPass)}
                style={{ background: "none", border: "none", cursor: "pointer", color: C.slateL, fontSize: 16 }}
              >
                {showPass ? "🙈" : "👁"}
              </button>
            }
          />

          {error && (
            <div
              style={{
                padding: "10px 14px", borderRadius: 10,
                background: C.redLt, color: C.red,
                fontSize: 13, fontWeight: 500,
              }}
            >
              ⚠️ {error}
            </div>
          )}

          <Button
            onClick={handleSubmit}
            disabled={loading}
            fullWidth
            size="lg"
            style={{ marginTop: 4 }}
          >
            {loading ? <><Spinner size={16} /> Verificando...</> : "Ingresar"}
          </Button>
        </div>

        {/* Usuarios demo */}
        {IS_DEMO && (
          <div
            style={{
              marginTop: 24, padding: 14, borderRadius: 10,
              background: C.grayLt, fontSize: 12, color: C.slateL,
              lineHeight: 1.7,
            }}
          >
            <div style={{ fontWeight: 700, marginBottom: 4, color: C.slate }}>
              👤 Usuarios demo — contraseña: <code>spvr2026</code>
            </div>
            <div>Analista: ana@spvr.com</div>
            <div>Gerente: carlos@spvr.com</div>
            <div>Vendedor: juan@spvr.com</div>
            <div>Admin: admin@spvr.com · Auditor: audit@spvr.com</div>
          </div>
        )}

        <div style={{ textAlign: "center", marginTop: 20, fontSize: 12, color: C.slateL }}>
          ¿No tienes cuenta?{" "}
          <span style={{ color: C.coral, cursor: "pointer" }}>
            Contacta con tu administrador de sistema
          </span>
        </div>
      </Card>
    </div>
  );
}
