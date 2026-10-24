"""Dump the Python index of a log as JSON lines, for the Go parity test."""
import json, sys, time
sys.path.insert(0, "src/python/veaf-tools")
from veaf_logs.buffer import FileBuffer
from veaf_logs.rules import Rules
from veaf_logs.store import LogStore

path, out = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else None)
t0 = time.perf_counter()
store = LogStore(Rules.load(), FileBuffer(path))
store.index_new()
t1 = time.perf_counter()
print(f"entries={len(store)} index={t1-t0:.3f}s", file=sys.stderr)
if out:
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        for i in range(len(store)):
            e = store.entry(i)
            f.write(json.dumps({"lineno": e.lineno, "level": e.level, "source": e.source,
              "label": e.source_label, "module": e.module, "noise": list(e.noise),
              "timestamp": e.timestamp, "subsystem": e.subsystem, "message": e.message,
              "conts": len(e.continuations)}, ensure_ascii=False) + "\n")
    print(f"dump={time.perf_counter()-t1:.3f}s", file=sys.stderr)
    print(store.counts_by_level(), store.counts_by_source(), store.counts_by_noise(), file=sys.stderr)
