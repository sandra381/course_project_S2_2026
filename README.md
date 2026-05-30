# SPVR — Frontend

Interfaz web del Sistema de Procesamiento de Ventas y Reportes.

## Correr la aplicación

```bash
# 1. Instalar dependencias
npm install

# 2. Correr la aplicación
npm run dev
```

Abre el navegador en **http://localhost:3000**

---

## Usuarios de prueba

| Email | Contraseña | Rol |
|---|---|---|
| ana@spvr.com | spvr2026 | Analista |
| carlos@spvr.com | spvr2026 | Gerente |
| juan@spvr.com | spvr2026 | Vendedor |
| admin@spvr.com | spvr2026 | Administrador |
| audit@spvr.com | spvr2026 | Auditor |

---

## Estructura

```
├── .github/workflows
├── frontend/
│    ├── src/
│    │   ├── api/
│    │   │   ├── client.js           ← Llamadas al API Gateway
│    │   │   └── demo.js             ← Datos de prueba
│    │   ├── components/
│    │   │   ├── Badge.jsx           ← Badges de estado
│    │   │   ├── Button.jsx          ← Botón reutilizable
│    │   │   ├── Card.jsx            ← Tarjeta con sombra
│    │   │   ├── Input.jsx           ← Campo de texto
│    │   │   ├── Sidebar.jsx         ← Menú lateral por rol
│    │   │   └── Spinner.jsx         ← Indicador de carga
│    │   ├── pages/
│    │   │   ├── Login.jsx           ← Pantalla 1
│    │   │   ├── Dashboard.jsx       ← Pantalla 2 (Analista)
│    │   │   ├── AdminDashboard.jsx  ← Pantalla 2 (Administrador)
│    │   │   ├── UploadCSV.jsx       ← Pantalla 3
│    │   │   ├── JobStatus.jsx       ← Pantalla 4
│    │   │   ├── History.jsx         ← Pantalla 5
│    │   │   ├── ReportDetail.jsx    ← Pantalla 6
│    │   │   ├── SellerDashboard.jsx ← Pantalla 7
│    │   │   └── ErrorLog.jsx        ← Pantalla 8
│    │   ├── App.jsx                 ← Router principal
│    │   ├── main.jsx                ← Entry point
│    │   └── styles.js               ← Paleta de colores y CSS global
│    ├── index.html
│    ├── vite.config.js
│    ├── package.json
│    └── .env.example
├── infra/
├── nube/
```

**NOTA:**  El frontend por el momento corre con valores default , falta hacer la conexion con nuestros servicios de AWS.