# Fixtures

## tempo_search_response.json

SYNTHESIZED fixture — not captured from a live Tempo instance.

Replace with a real captured response (see plan Task B.2 Step 1: `curl` the Grafana
Tempo datasource proxy) once Phase A.2 lands a Grafana service-account token.

## tempo_trace_response.json

SYNTHESIZED fixture — not captured from a live Tempo instance.

Matches the OTLP-shaped JSON envelope returned by Tempo's `/api/traces/{traceID}` endpoint
(via the Grafana datasource proxy at `/api/datasources/proxy/uid/tempo/api/traces/{id}`).

Structure:
- **Batch 1** — root span: `GET /api/properties/:id/availability`, 4820ms (service: `wander/api`)
  - Also contains 2 unique redis spans (count < 3, won't form repeat groups)
- **Batch 2** — 47 `prisma.unit.findUnique` child spans, sequential, total ~3186ms
  - Classified as `n_plus_one_suspect` by `compute_repeat_groups`
- **Batch 3** — 6 `http.client GET hostaway.com/listings/{uuid}/calendar` child spans, sequential, total ~1000ms
  - After UUID normalization all 6 collapse to one operation key
  - Classified as `sequential_external` by `compute_repeat_groups`

Replace with a real Tempo capture (see plan Phase A.2) once the Grafana SA token lands.
