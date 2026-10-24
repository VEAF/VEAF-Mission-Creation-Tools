"""Time the Python filters on a real journal, the counterpart of `TestBigJournalTimings`.

Run from the repository root:

    poetry run python src/go/veaf-logs/testdata/time_filters.py <journal>

and, in `src/go/veaf-logs`, `VEAF_LOGS_BIG=<journal> go test ./internal/logcore -run BigJournal -v`.
Both print, per case, the time, the number of visible entries and a digest of them: equal digests
mean equal results.
"""

from __future__ import annotations

import hashlib
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "src" / "python" / "veaf-tools"))

from veaf_logs.buffer import BytesBuffer  # noqa: E402
from veaf_logs.filters import FilterSet, evaluate  # noqa: E402
from veaf_logs.rules import Rules  # noqa: E402
from veaf_logs.store import LogStore  # noqa: E402

# Same cases, same order, as `BigJournalCases` in filters_bench_test.go.
CASES = [
    ("diagnostic", {"levels": {"INFO": "context", "DEBUG": "context", "TRACE": "context"}, "context_lines": 3}),
    ("plain SCRIPTING", {"text_filters": [{"pattern": "SCRIPTING"}]}),
    ("regex VEAF W/E", {"text_filters": [{"pattern": r"VEAF\|[WE]\|", "mode": "regex"}]}),
    ("glob + search ±2", {"text_filters": [{"pattern": "*error*lua*", "mode": "glob"}], "search_context_lines": 2}),
    ("inverted, case-sensitive", {"text_filters": [{"pattern": "INFO", "case_sensitive": True, "invert": True}]}),
]


def main() -> None:
    store = LogStore(Rules.load(), BytesBuffer(Path(sys.argv[1]).read_bytes()))
    store.index_new()
    print(f"{len(store)} entries")
    for name, raw in CASES:
        filters = FilterSet.from_dict(raw)
        started = time.perf_counter()
        visible = evaluate(store, filters)
        elapsed = time.perf_counter() - started
        digest = hashlib.sha1(json.dumps(visible, separators=(",", ":")).encode()).hexdigest()
        print(f"{name:<26} {elapsed:6.2f} s  {len(visible):7d} visible  {digest}")


if __name__ == "__main__":
    main()
