import json
import sys
import unittest
from pathlib import Path

# Make the skill module importable when running from repo root.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tempo_slow_requests import aggregate_rank


FIXTURES = Path(__file__).parent / "fixtures"


class RankAggregationTest(unittest.TestCase):
    def setUp(self) -> None:
        with open(FIXTURES / "tempo_search_response.json") as f:
            self.search = json.load(f)

    def test_returns_list_of_route_groups(self) -> None:
        ranked = aggregate_rank(self.search, top=6)
        self.assertIsInstance(ranked, list)
        self.assertLessEqual(len(ranked), 6)

    def test_each_entry_has_required_keys(self) -> None:
        ranked = aggregate_rank(self.search, top=6)
        if not ranked:
            self.skipTest("no fixture data")
        required = {"rank", "service", "method", "route", "p99_ms", "p50_ms",
                    "count", "span_count_p50", "sample_trace_id", "tempo_explore_url"}
        self.assertLessEqual(required, set(ranked[0].keys()))

    def test_sorted_by_p99_descending(self) -> None:
        ranked = aggregate_rank(self.search, top=6)
        if len(ranked) < 2:
            self.skipTest("need >=2 entries")
        for a, b in zip(ranked, ranked[1:]):
            self.assertGreaterEqual(a["p99_ms"], b["p99_ms"])

    def test_rank_field_is_1_indexed_and_dense(self) -> None:
        ranked = aggregate_rank(self.search, top=6)
        for i, r in enumerate(ranked, start=1):
            self.assertEqual(r["rank"], i)

    def test_method_and_route_split_correctly(self) -> None:
        ranked = aggregate_rank(self.search, top=6)
        for r in ranked:
            # method should be all-caps HTTP verb, route should start with /
            self.assertRegex(r["method"], r"^[A-Z]+$")
            self.assertTrue(r["route"].startswith("/"))

    def test_top_n_caps_results(self) -> None:
        ranked = aggregate_rank(self.search, top=2)
        self.assertLessEqual(len(ranked), 2)

    def test_count_matches_input_traces_per_group(self) -> None:
        # availability route has 5 traces in the fixture; its count must be 5.
        ranked = aggregate_rank(self.search, top=6)
        avail = next((r for r in ranked if "availability" in r["route"]), None)
        if avail is None:
            self.skipTest("availability route not in top results")
        self.assertEqual(avail["count"], 5)


class PercentileTest(unittest.TestCase):
    def test_p99_returns_max_for_small_n(self) -> None:
        from tempo_slow_requests import _percentile
        self.assertEqual(_percentile([1, 2, 3, 4, 5], 99), 5)
        self.assertEqual(_percentile([10, 20], 99), 20)
        self.assertEqual(_percentile([42], 99), 42)

    def test_p50_returns_median_ish(self) -> None:
        from tempo_slow_requests import _percentile
        # nearest-rank median of 5 values: ceil(0.5*5)=3, index 2 → middle value
        self.assertEqual(_percentile([1, 2, 3, 4, 5], 50), 3)

    def test_empty_returns_zero(self) -> None:
        from tempo_slow_requests import _percentile
        self.assertEqual(_percentile([], 99), 0)


if __name__ == "__main__":
    unittest.main()
