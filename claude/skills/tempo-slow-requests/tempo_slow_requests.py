#!/usr/bin/env python3
"""tempo-slow-requests: rank slow API routes via Tempo, or fetch one trace."""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import statistics
import sys
import time
import urllib.parse
import urllib.request
from collections import defaultdict
from typing import Any


def env(name: str) -> str:
    value = os.environ.get(name)
    if value is None:
        sys.stderr.write(f"missing required env var: {name}\n")
        sys.exit(2)
    return value


def fetch_tempo_search(
    base_url: str, token: str, traceql: str, start_unix: int, end_unix: int, limit: int = 1000
) -> dict:
    qs = urllib.parse.urlencode([
        ("q", traceql),
        ("limit", str(limit)),
        ("start", str(start_unix)),
        ("end", str(end_unix)),
    ])
    url = f"{base_url}/api/datasources/proxy/uid/tempo/api/search?{qs}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def aggregate_rank(search_response: dict, top: int) -> list[dict[str, Any]]:
    """Group Tempo search results by (method, route); compute p99 + p50 + count + sample."""
    by_key: dict[tuple[str, str], list[dict]] = defaultdict(list)

    for t in search_response.get("traces", []):
        name = t.get("rootTraceName", "")
        if " " not in name:
            continue
        method, route = name.split(" ", 1)
        by_key[(method, route)].append(t)

    results: list[dict[str, Any]] = []
    for (method, route), traces in by_key.items():
        durations = sorted(int(t.get("durationMs", 0)) for t in traces)
        if not durations:
            continue
        p99_ms = _percentile(durations, 99)
        p50_ms = _percentile(durations, 50)
        sample = min(
            (t for t in traces if int(t.get("durationMs", 0)) >= p99_ms),
            key=lambda x: int(x.get("durationMs", 0)),
            default=traces[-1],
        )
        results.append({
            "service": traces[0].get("rootServiceName", ""),  # per-group, not global
            "method": method,
            "route": route,
            "p99_ms": p99_ms,
            "p50_ms": p50_ms,
            "count": len(traces),
            "span_count_p50": int(statistics.median([t.get("spanCount", 0) for t in traces])),
            "sample_trace_id": sample.get("traceID", ""),
        })

    results.sort(key=lambda r: r["p99_ms"], reverse=True)
    results = results[:top]
    for i, r in enumerate(results, start=1):
        r["rank"] = i
        r["tempo_explore_url"] = build_explore_url(r["sample_trace_id"])
    return results


def _percentile(sorted_values: list[int], p: int) -> int:
    if not sorted_values:
        return 0
    # Nearest-rank: ceil(p/100 * N) - 1, clamped to valid index range.
    k = max(0, min(len(sorted_values) - 1, math.ceil(p * len(sorted_values) / 100) - 1))
    return sorted_values[k]


def build_explore_url(trace_id: str) -> str:
    base = os.environ.get("GRAFANA_BASE_URL", "")
    if not base or not trace_id:
        return ""
    payload = {
        "datasource": "tempo",
        "queries": [{
            "refId": "A", "queryType": "traceql",
            "query": trace_id, "datasource": {"uid": "tempo"},
        }],
    }
    return f"{base}/explore?left={urllib.parse.quote(json.dumps(payload))}"


def fetch_tempo_trace(base_url: str, token: str, trace_id: str) -> dict:
    url = f"{base_url}/api/datasources/proxy/uid/tempo/api/traces/{trace_id}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def flatten_trace(raw: dict) -> dict[str, Any]:
    """Flatten a Tempo /api/traces response into a structured representation with repeat_groups."""
    spans: list[dict[str, Any]] = []
    trace_id = ""
    for batch in raw.get("batches", []):
        resource_attrs = _attrs_to_dict(batch.get("resource", {}).get("attributes", []))
        service = resource_attrs.get("service.name", "")
        for scope in batch.get("scopeSpans", []):
            for s in scope.get("spans", []):
                trace_id = trace_id or s.get("traceId", "")
                spans.append({
                    "span_id": s.get("spanId", ""),
                    "parent_span_id": s.get("parentSpanId", ""),
                    "name": s.get("name", ""),
                    "service": service,
                    "attrs": _attrs_to_dict(s.get("attributes", [])),
                    "start_ns": int(s.get("startTimeUnixNano", 0)),
                    "end_ns": int(s.get("endTimeUnixNano", 0)),
                })

    if not spans:
        return {
            "trace_id": trace_id,
            "root": {"service": "", "operation": "", "duration_ms": 0},
            "spans": [],
            "repeat_groups": [],
            "loki_correlation_url": build_loki_correlation_url(trace_id),
        }

    root = next((s for s in spans if not s["parent_span_id"]), spans[0])
    root_duration_ms = (root["end_ns"] - root["start_ns"]) // 1_000_000

    return {
        "trace_id": trace_id,
        "root": {
            "service": root.get("service", ""),
            "operation": root.get("name", ""),
            "duration_ms": root_duration_ms,
        },
        "spans": spans,
        "repeat_groups": compute_repeat_groups(spans, root_duration_ms),
        "loki_correlation_url": build_loki_correlation_url(trace_id),
    }


def compute_repeat_groups(
    spans: list[dict], root_duration_ms: int  # noqa: ARG001 — reserved for V1.1 threshold filtering
) -> list[dict[str, Any]]:
    """Group spans by normalized operation name; return groups with count >= 3, sorted by total_ms desc."""
    by_op: dict[str, list[dict]] = defaultdict(list)
    for s in spans:
        op = _normalize_operation(s["name"])
        by_op[op].append(s)

    groups: list[dict[str, Any]] = []
    for op, ss in by_op.items():
        if len(ss) < 3:
            continue
        total_ms = sum(s["end_ns"] - s["start_ns"] for s in ss) // 1_000_000
        groups.append({
            "operation": op,
            "count": len(ss),
            "total_ms": total_ms,
            "pattern": _classify_repeat_pattern(op, ss),
        })

    groups.sort(key=lambda g: g["total_ms"], reverse=True)
    return groups


def _normalize_operation(name: str) -> str:
    """Replace UUIDs and long numeric IDs in operation names with :id placeholder."""
    s = re.sub(
        r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
        ":id",
        name,
    )
    s = re.sub(r"\b\d{6,}\b", ":id", s)
    return s


_HTTP_VERBS = ("get", "post", "put", "patch", "delete", "head", "options")


def _classify_repeat_pattern(op: str, spans: list[dict]) -> str:
    if op.startswith("prisma."):
        return "n_plus_one_suspect"

    op_lower = op.lower()
    # Cover both OTel naming conventions:
    #   New (2026-era): "http.client", "GET https://..." → first token is verb
    #   Old (<v0.44):   "HTTP GET", "HTTP POST" → second token is verb
    is_http_client = (
        op.startswith("http.client")
        or any(op_lower.startswith(f"{verb} http") for verb in _HTTP_VERBS)
        or any(op_lower.startswith(f"http {verb}") for verb in _HTTP_VERBS)
    )
    if is_http_client:
        sorted_spans = sorted(spans, key=lambda s: s["start_ns"])
        sequential = all(
            sorted_spans[i + 1]["start_ns"] >= sorted_spans[i]["end_ns"]
            for i in range(len(sorted_spans) - 1)
        )
        return "sequential_external" if sequential else "other_repeat"

    return "other_repeat"


_OTLP_SCALAR_VALUE_KEYS = ("stringValue", "intValue", "doubleValue", "boolValue")


def _attrs_to_dict(attrs: list[dict]) -> dict[str, str]:
    """Flatten OTLP attribute list to {key: scalar_str}. Non-scalar values
    (arrayValue, kvlistValue, bytesValue) are skipped — `str(dict_or_list)`
    yields a Python repr, which is not what callers want."""
    out: dict[str, str] = {}
    for a in attrs or []:
        k = a.get("key", "")
        v = a.get("value", {})
        if not isinstance(v, dict):
            continue
        for scalar_key in _OTLP_SCALAR_VALUE_KEYS:
            if scalar_key in v and v[scalar_key] is not None:
                out[k] = str(v[scalar_key])
                break
    return out


def build_loki_correlation_url(trace_id: str) -> str:
    base = os.environ.get("GRAFANA_BASE_URL", "")
    service = os.environ.get("LOKI_SERVICE_NAME", "")
    if not base or not trace_id or not service:
        return ""
    logql = f'{{service_name="{service}"}} |= "{trace_id}"'
    payload = {
        "datasource": "loki",
        "queries": [{
            "refId": "A",
            "expr": logql,
            "datasource": {"uid": "loki"},
        }],
    }
    return f"{base}/explore?left={urllib.parse.quote(json.dumps(payload))}"


def parse_window_to_unix(window: str, now_unix: int) -> tuple[int, int]:
    if not window or window[-1] not in {"m", "h", "d"} or not window[:-1].isdigit():
        raise ValueError(f"invalid window {window!r}; use Nm, Nh, or Nd")
    unit = window[-1]
    qty = int(window[:-1])
    seconds = {"m": 60, "h": 3600, "d": 86400}[unit] * qty
    return now_unix - seconds, now_unix


def cmd_rank(args: argparse.Namespace) -> int:
    base_url = env("GRAFANA_BASE_URL")
    token = env("GRAFANA_SA_TOKEN")
    now = int(time.time())
    start_unix, end_unix = parse_window_to_unix(args.window, now)
    traceql = (
        f'{{ resource.service.name = "{args.service}" '
        f'&& span.http.route != "" }}'
    )
    search = fetch_tempo_search(base_url, token, traceql, start_unix, end_unix)
    ranked = aggregate_rank(search, top=args.top)
    json.dump(ranked, sys.stdout)
    sys.stdout.write("\n")
    return 0


def cmd_trace(args: argparse.Namespace) -> int:
    base_url = env("GRAFANA_BASE_URL")
    token = env("GRAFANA_SA_TOKEN")
    raw = fetch_tempo_trace(base_url, token, args.id)
    out = flatten_trace(raw)
    json.dump(out, sys.stdout)
    sys.stdout.write("\n")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="tempo-slow-requests")
    sub = parser.add_subparsers(dest="op", required=True)

    rank = sub.add_parser("rank")
    rank.add_argument("--service", required=True)
    rank.add_argument("--window", default="24h",
                      help="time window: Nm/Nh/Nd (default: 24h)")
    rank.add_argument("--top", type=int, default=6)
    rank.set_defaults(func=cmd_rank)

    trace = sub.add_parser("trace")
    trace.add_argument("--id", required=True)
    trace.set_defaults(func=cmd_trace)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
