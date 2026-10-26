"""Compare two parity dumps (JSON lines) record by record; exit 1 on any difference."""
import json
import sys

a_path, b_path = sys.argv[1], sys.argv[2]
shown = diffs = n = 0
with open(a_path, encoding="utf-8") as fa, open(b_path, encoding="utf-8") as fb:
    for n, (la, lb) in enumerate(zip(fa, fb), 1):
        ra, rb = json.loads(la), json.loads(lb)
        if ra != rb:
            diffs += 1
            if shown < 5:
                shown += 1
                for key in ra:
                    if ra[key] != rb.get(key):
                        print(f"record {n} field {key}: python={ra[key]!r} go={rb.get(key)!r}")
    extra = sum(1 for _ in fa) + sum(1 for _ in fb)
if extra:
    print(f"different record counts (after {n} common)")
print(f"{n} records compared, {diffs} differ")
sys.exit(1 if diffs or extra else 0)
