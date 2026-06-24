# Final Presentation — Candidate Menu

Equipo: Gabriela Navarro, Diego Sican, Sandra Soria
Repositorio: `sandra381/course_project_S2_2026`
Curso: Optimizaciones y Desempeño — Session 10

Estas son las áreas de comportamiento candidatas para el cambio en vivo de
los Segmentos D y E. El instructor seleccionará una y especificará el
comportamiento exacto a implementar. Ninguna de las tres requiere nuevo
esquema de base de datos ni modificar más de un archivo — las tres viven en
`infra/modules/compute/handler_api.py`. El código real del cambio no se
pre-escribe ni se pre-stagea; solo se rehearsa la mecánica (ubicación del
handler, build/deploy, cómo abrir el PR).

---

## Candidato 1 — Límite configurable en `GET /jobs`

**Title:** Límite configurable en listado de jobs

**Observable behavior:** El endpoint `GET /jobs` siempre devuelve un
máximo fijo de resultados (`LIMIT 20` fijo en el SQL), sin posibilidad de
pedir un número distinto desde el cliente. El cambio observable sería que
la cantidad de elementos en la respuesta varíe según un parámetro provisto
por el cliente, en lugar de quedarse siempre en el mismo tope.

**Affected endpoint and handler:** `GET /jobs` —
`infra/modules/compute/handler_api.py`, bloque
`elif method == "GET" and path == "/jobs":` (línea ~269).

**Verification method:**
```
curl "https://<endpoint-staging>/jobs?limit=3"
```
El array `"jobs": [...]` debe contener exactamente 3 elementos (o menos, si
hay menos de 3 jobs en total), en contraste con la llamada sin el
parámetro, que devuelve hasta el tope actual.

**Rough scope:** 2-3 líneas — leer el parámetro de la query string y usar
ese valor como parámetro de `LIMIT` en el SQL existente, en lugar del
número fijo.

---

## Candidato 2 — Bloquear doble-encolado en `POST /jobs/enqueue`

**Title:** Validar estado antes de re-encolar un job

**Observable behavior:** `POST /jobs/enqueue` acepta el mismo `job_id` las
veces que sea, sin revisar su estado actual — siempre responde
`202 enqueued`, aunque el job ya esté `COMPLETADO` o `PROCESANDO`. (El
Lambda Worker ya protege la integridad del dato descartando estos mensajes
duplicados, pero el cliente recibe una respuesta de éxito engañosa.) El
cambio observable sería que una segunda solicitud sobre un job que ya no
está `PENDIENTE` devuelva un error en lugar de un éxito falso.

**Affected endpoint and handler:** `POST /jobs/enqueue` —
`infra/modules/compute/handler_api.py`, bloque
`elif method == "POST" and "/jobs/enqueue" in path:` (línea ~361).

**Verification method:**
```
curl -X POST "https://<endpoint-staging>/jobs/enqueue" -H "Content-Type: application/json" -d '{"job_id": 5}'
```
Llamando el endpoint dos veces seguidas con el mismo `job_id`: la primera
llamada (job en `PENDIENTE`) devuelve `202`; la segunda llamada inmediata
(job ya en `PROCESANDO`) debe devolver `400` con un mensaje descriptivo.

**Rough scope:** 2-3 líneas — agregar el estado al `SELECT` que ya existe
y, justo después de validar que el job exista, agregar una condición que
rechace la solicitud si el estado no es `PENDIENTE`.

---

## Candidato 3 — Promedio agregado en `GET /seller/history`

**Title:** Campo agregado `promedio_clientes` en historial de vendedor

**Observable behavior:** `GET /seller/history` devuelve la lista de
reportes individuales de un vendedor (cada uno con su propio
`clientes_atendidos`), pero no incluye ningún resumen o promedio calculado
sobre esa lista. El cambio observable sería un nuevo campo en la respuesta
con el promedio calculado sobre el conjunto completo de reportes.

**Affected endpoint and handler:** `GET /seller/history` —
`infra/modules/compute/handler_api.py`, bloque
`elif method == "GET" and path == "/seller/history":` (línea ~611).

**Verification method:**
```
curl "https://<endpoint-staging>/seller/history?nombre=<vendedor>"
```
La respuesta debe incluir un campo nuevo a nivel raíz, `"promedio_clientes"`,
calculado como la suma de `clientes_atendidos` de todos los reportes
dividida entre la cantidad de reportes.

**Rough scope:** 4-5 líneas — calcular el promedio sobre los resultados
después de obtenerlos, con manejo del caso de lista vacía para evitar
división por cero, y agregar el campo al diccionario de respuesta.

---
