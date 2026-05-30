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

## Conectar a AWS (después del terraform apply)

1. Corre los outputs de Terraform:
   ```bash
   cd ../infra
   terraform output api_endpoint
   ```

2. Crea el archivo `.env` en la carpeta `frontend/`:
   ```bash
   cp .env.example .env
   ```

3. Pega el endpoint en `.env`:
   ```
   VITE_API_URL=https://abc123.execute-api.us-east-1.amazonaws.com
   ```

4. Reinicia el servidor:
   ```bash
   npm run dev
   ```

La app automáticamente deja de usar datos demo y empieza a llamar al API Gateway real.

## Build para producción

```bash
npm run build
# Genera la carpeta dist/ lista para subir a S3 o CloudFront
```
