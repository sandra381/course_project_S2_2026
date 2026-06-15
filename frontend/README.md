# SPVR — Frontend

Interfaz web del Sistema de Procesamiento de Ventas y Reportes.

## Estructura

```
frontend/
├── src/
│   ├── api/
│   │   ├── client.js     ← Todas las llamadas al API Gateway
│   │   └── demo.js       ← Datos de prueba (sin necesitar AWS)
│   ├── components/
│   │   ├── Badge.jsx     ← Badges de estado (COMPLETADO, FALLIDO...)
│   │   ├── Button.jsx    ← Botón reutilizable
│   │   ├── Card.jsx      ← Tarjeta con sombra
│   │   ├── Input.jsx     ← Campo de texto
│   │   ├── Sidebar.jsx   ← Menú lateral con navegación por rol
│   │   └── Spinner.jsx   ← Indicador de carga
│   ├── pages/
│   │   ├── Login.jsx           ← Pantalla 1
│   │   ├── Dashboard.jsx       ← Pantalla 2
│   │   ├── UploadCSV.jsx       ← Pantalla 3
│   │   ├── JobStatus.jsx       ← Pantalla 4
│   │   ├── History.jsx         ← Pantallas 5 y 6
│   │   ├── SellerDashboard.jsx ← Pantalla 7
│   │   └── ErrorLog.jsx        ← Pantalla 8
│   ├── App.jsx           ← Router principal
│   ├── main.jsx          ← Entry point
│   └── styles.js         ← Paleta de colores y CSS global
├── index.html
├── vite.config.js
├── package.json
└── .env.example
```

---

## Estado de integración con AWS

El frontend está conectado únicamente con **Lambda API** a través del API Gateway.
La integración con Lambda Worker (procesamiento asíncrono vía SQS) queda pendiente para E4.

| Pantalla | Ruta AWS | Estado |
|---|---|---|
| Login | `POST /login` → Lambda API → RDS | ✅ Conectado |
| Dashboard | `GET /jobs` → Lambda API → RDS | ✅ Conectado |
| Cargar CSV | `POST /upload` → Lambda API → RDS + S3 | ✅ Conectado |
| JobStatus | `GET /jobs/{id}` → Lambda API → RDS | ✅ Conectado |
| Historial | `GET /reports` → Lambda API → RDS | ⏳ Sin datos (requiere Worker — E4 ) |
| Historial descarga | `GET /reports/{id}/download` → Lambda API → S3 | ⏳ Sin PDFs (requiere Worker — E4) |
| ErrorLog | `GET /errors` → Lambda API → RDS | ⏳ Sin datos reales (requiere Worker — E4) |
| SellerDashboard | — | 📋 Datos demo hardcodeados |
| AdminDashboard | — | 📋 Datos demo hardcodeados |
| ReportDetail | — | 📋 Datos demo hardcodeados |

> **Nota:** Historial, ErrorLog y descarga de PDFs dependen del Lambda Worker,
> que procesa los CSV y genera reportes. Su implementación completa está planificada para E4
> junto con la integración de SQS y SES.

---

## Correr en modo demo (sin AWS)

```bash
cd frontend
npm install
npm run dev
# Abre http://localhost:3000
```

Usuarios disponibles (contraseña: `spvr2026`):

| Email | Rol |
|---|---|
| ana@spvr.com | Analista |
| carlos@spvr.com | Gerente |
| juan@spvr.com | Vendedor |
| admin@spvr.com | Administrador |
| audit@spvr.com | Auditor |

Cuando `VITE_API_URL` está vacío en el `.env`, la app usa automáticamente
los datos locales de `demo.js` para todas las pantallas.

---

## Conectar a AWS (después del terraform apply)

1. Obtén el endpoint del API Gateway:
   ```bash
   cd ../infra
   terraform output api_endpoint
   ```

2. Inicializa la base de datos (solo la primera vez):
   ```bash
   curl -X POST https://<api_endpoint>/setup
   ```

3. Crea el archivo `.env` en la carpeta `frontend/`:
   ```bash
   cp .env.example .env
   ```

4. Pega el endpoint en `.env`:
   ```
   VITE_API_URL=https://<api_endpoint>
   ```

5. Reinicia el servidor:
   ```bash
   npm run dev
   ```

La app automáticamente deja de usar datos demo y empieza a llamar al API Gateway real.

---

