import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tempo_slow_requests import flatten_trace, compute_repeat_groups


FIXTURES = Path(__file__).parent / "fixtures"


class TraceFlattenTest(unittest.TestCase):
    def setUp(self) -> None:
        with open(FIXTURES / "tempo_trace_response.json") as f:
            self.raw = json.load(f)

    def test_returns_trace_id_root_spans(self) -> None:
        out = flatten_trace(self.raw)
        self.assertIn("trace_id", out)
        self.assertIn("root", out)
        self.assertIn("spans", out)
        self.assertIsInstance(out["spans"], list)
        self.assertGreater(len(out["spans"]), 0)

    def test_root_has_service_operation_duration(self) -> None:
        out = flatten_trace(self.raw)
        self.assertIn("service", out["root"])
        self.assertIn("operation", out["root"])
        self.assertIn("duration_ms", out["root"])
        self.assertIsInstance(out["root"]["duration_ms"], int)
        # The fixture's root duration is 4820ms.
        self.assertEqual(out["root"]["duration_ms"], 4820)

    def test_each_span_has_required_fields(self) -> None:
        out = flatten_trace(self.raw)
        required = {"span_id", "parent_span_id", "name", "service", "attrs", "start_ns", "end_ns"}
        for span in out["spans"]:
            self.assertEqual(required, set(span.keys()) & required)

    def test_repeat_groups_present_in_output(self) -> None:
        out = flatten_trace(self.raw)
        self.assertIn("repeat_groups", out)
        self.assertIsInstance(out["repeat_groups"], list)

    def test_loki_correlation_url_present(self) -> None:
        out = flatten_trace(self.raw)
        self.assertIn("loki_correlation_url", out)


class RepeatGroupsTest(unittest.TestCase):
    def setUp(self) -> None:
        with open(FIXTURES / "tempo_trace_response.json") as f:
            self.flat = flatten_trace(json.load(f))

    def test_returns_list(self) -> None:
        self.assertIsInstance(self.flat["repeat_groups"], list)

    def test_minimum_count_three(self) -> None:
        for g in self.flat["repeat_groups"]:
            self.assertGreaterEqual(g["count"], 3)

    def test_each_group_has_required_keys(self) -> None:
        required = {"operation", "count", "total_ms", "pattern"}
        for g in self.flat["repeat_groups"]:
            self.assertEqual(required, set(g.keys()) & required)

    def test_pattern_is_valid(self) -> None:
        valid = {"n_plus_one_suspect", "sequential_external", "other_repeat"}
        for g in self.flat["repeat_groups"]:
            self.assertIn(g["pattern"], valid)

    def test_prisma_repeat_classified_as_n_plus_one(self) -> None:
        prisma_groups = [g for g in self.flat["repeat_groups"]
                         if g["operation"].startswith("prisma.")]
        if not prisma_groups:
            self.skipTest("fixture has no prisma group")
        for g in prisma_groups:
            self.assertEqual(g["pattern"], "n_plus_one_suspect")

    def test_groups_sorted_by_total_ms_desc(self) -> None:
        groups = self.flat["repeat_groups"]
        if len(groups) < 2:
            self.skipTest("need >= 2 groups")
        for a, b in zip(groups, groups[1:]):
            self.assertGreaterEqual(a["total_ms"], b["total_ms"])


class NormalizeOperationTest(unittest.TestCase):
    def test_uuids_replaced_with_id_placeholder(self) -> None:
        from tempo_slow_requests import _normalize_operation
        op = "http.client GET hostaway.com/listings/9f0a3d4e-1234-5678-9abc-def012345678/calendar"
        self.assertEqual(
            _normalize_operation(op),
            "http.client GET hostaway.com/listings/:id/calendar",
        )

    def test_long_numeric_ids_replaced(self) -> None:
        from tempo_slow_requests import _normalize_operation
        self.assertEqual(_normalize_operation("api/users/1234567"), "api/users/:id")

    def test_short_numbers_unchanged(self) -> None:
        from tempo_slow_requests import _normalize_operation
        # 4-digit numbers are too short to flag as IDs
        self.assertEqual(_normalize_operation("api/v1/foo"), "api/v1/foo")


if __name__ == "__main__":
    unittest.main()
