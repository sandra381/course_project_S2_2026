environment       = "staging"
project_name      = "oyd-project"
region            = "us-east-1"
app_bucket_prefix = "app-assets"
db_username       = "admin"

# ─── DIFERENCIA 1 — CIDR separado ─────────────────────────────────────────────
# Staging usa 10.1.x.x para evitar conflicto con dev (10.0.x.x)
# si ambos ambientes corren al mismo tiempo en la misma cuenta AWS.
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]

availability_zones = ["us-east-1a", "us-east-1b"]
single_nat_gateway = true
health_check_path  = "/"

# ─── DIFERENCIA 2 — Retención de mensajes más larga ───────────────────────────
# Staging retiene mensajes 3 días (vs 1 día en dev) para tener más tiempo
# de inspeccionar el comportamiento antes de llegar a producción.
queue_name_prefix             = "spvr-jobs"
visibility_timeout_seconds    = 60
message_retention_seconds     = 259200
max_receive_count             = 3
dlq_message_retention_seconds = 1209600

# ─── DIFERENCIA 3 — Batch size más alto ───────────────────────────────────────
# Staging procesa 5 mensajes a la vez (vs 1 en dev) para simular
# carga real con múltiples CSVs en cola simultáneamente.
batch_size                         = 5
maximum_batching_window_in_seconds = 30
bisect_batch_on_function_error     = true

# ─── SCHEDULER ────────────────────────────────────────────────────────────────
schedule_expression = "rate(1 hour)"
scheduler_timezone  = "America/Guatemala"
stale_hours         = 2