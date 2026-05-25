---
name: tempo-slow-requests
description: Rank slow API routes from Tempo by p99 latency, or fetch and pre-process a single trace. Use this when the user asks "what was slow on <service> recently?" or wants per-trace span analysis (repeat groups, pattern detection). Reads from Grafana datasource proxy via HTTPS — requires GRAFANA_BASE_URL and GRAFANA_SA_TOKEN env vars.
---

# tempo-slow-requests

Two operations exposed via the implementation script `tempo_slow_requests.py`:

- **`rank`** (default): rank slow routes for a service by p99 latency over a time window.
- **`trace`**: fetch a single trace and return a flattened span tree + repeat-group analysis.

## Usage

```bash
python3 tempo_slow_requests.py rank --service wander/api --window 24h --top 6
python3 tempo_slow_requests.py trace --id <trace-id>
```

Outputs JSON to stdout. See `README.md` for output schemas and required env vars.
