# tempo-slow-requests

Single-file Python 3 skill that queries Tempo via Grafana's datasource proxy.

## Dependencies

Python 3 standard library only — `urllib.request`, `json`, `argparse`, `unittest`. No `pip install`.

## Required env vars

- `GRAFANA_BASE_URL` — e.g. `https://grafana.example.com`
- `LOKI_SERVICE_NAME` — optional; if set, traces returned by `trace` include a Loki correlation URL scoped to `{service_name="<value>"}`
- `GRAFANA_SA_TOKEN` — service-account token with `Datasources:Read`

## Operations

### `rank`

```
python3 tempo_slow_requests.py rank --service <name> --window <duration> --top <N>
```

Defaults: `--window 24h --top 6`.

Output (JSON to stdout): array of objects with `rank`, `service`, `method`, `route`, `p99_ms`, `p50_ms`, `count`, `span_count_p50`, `sample_trace_id`, `tempo_explore_url`.

### `trace`

```
python3 tempo_slow_requests.py trace --id <trace-id>
```

Output (JSON to stdout): object with `trace_id`, `root`, `spans`, `repeat_groups`, `loki_correlation_url`.

## Tests

```
python3 -m unittest discover skills/tempo-slow-requests/tests
```
