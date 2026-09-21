# 02 — The workflow prints what it spends, and reads back all four keys

Status: ✅ done

Type: fix

## The problem

Nothing in the pipeline ever said how many KV writes a run costs. The quota was discovered by
reading a failure message, three merges after the first one broke. A cost that is never printed is
a cost nobody watches, and ticket 01 only holds as long as nobody reintroduces a per-chunk key.

## What to do

1. `build-index.mjs` prints the write cost of the upload it just prepared, and the cap it is
   measured against.
2. The workflow puts **four** keys (`idx:vec:{fr,en}`, `idx:txt:{fr,en}`) and writes the same figure
   to the job summary, so it is visible without opening the log.
3. The verification step reads **all four** back from the **remote** namespace and byte-compares
   them. The bulk-file special case goes away with the bulk file: `--txt` becomes the same plain
   comparison as `--vec`.

The `KV_MISSING_SENTINEL` handling stays exactly as it is. `kv key get` on an absent key still
exits 0 and prints `Value not found` to stdout, and that is still the only reason a missing key is
distinguishable from a value.

## Definition of done

- [ ] The write cost is printed by the build and lands in the job summary
- [ ] Four keys uploaded, four keys read back from `--remote` and compared byte for byte
- [ ] `verify-index-upload.mjs` no longer parses a bulk file; `--print-last-key` is gone with it
- [ ] Its tests follow the same path
