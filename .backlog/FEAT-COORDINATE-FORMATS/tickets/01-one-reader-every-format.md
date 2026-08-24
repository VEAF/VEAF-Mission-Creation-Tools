# 01 — one reader, every format a pilot can read off his screen

Status: ✅ done

Part of [FEAT-COORDINATE-FORMATS](../PRD.md).

Work on `veaf.computeLLFromString` in `src/scripts/veaf/veaf.lua`:

1. fix the accumulator (`-1` → `0`) — one arc-second, about 31 m, on every DMS coordinate in VEAF;
2. accept MGRS with spaces and without the `u` prefix, keeping the current form working;
3. accept DMS written with spaces or with `°`/`'`/`"`;
4. refuse an odd number of MGRS digits instead of halving it;
5. keep decimal degrees working, and cover them.

The tests enumerate the format table from the PRD rather than sampling it: this is a family of inputs, and
a sampled test here leaves siblings broken.
