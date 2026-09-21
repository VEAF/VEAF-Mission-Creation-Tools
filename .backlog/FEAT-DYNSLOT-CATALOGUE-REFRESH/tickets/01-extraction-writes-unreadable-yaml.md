# 01 — The extractor writes a catalogue it cannot read back

Status: ✅ done
Type: fix

## The defect

`AircraftGroupsExtractorWorker._write_structure`
([`aircrafts_injector_worker.py:1531`](../../../src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py))
writes the catalogue with `open(path, "w")` — no `encoding`, so the process locale's codepage, which
is `cp1252` on a French Windows. `yaml.dump` is called with `allow_unicode=True`, so any non-ASCII
character in a livery name, a callsign or a group name is written as a cp1252 byte.

Every reader in the same file passes `encoding="utf-8"`:

| line | reader |
|------|--------|
| 162 | `AircraftGroupsValidator.load` |
| 554 | `AircraftGroupsInjectorWorker.load_yaml_data` |
| 1433 | `_merge_into` (the `--merge` path) |

So the extraction produces a file the tool cannot consume. Measured on Reaper's extract of
2026-09-21, which carries `Armée de l'air11` and `Déchet11` as callsigns:

```
utf-8 read FAILS -> 'utf-8' codec can't decode byte 0xe9 in position 195704: invalid continuation byte
```

Reproduced from scratch:

```python
with open(tmp, "w") as f:                      # exactly line 1531
    yaml.dump({"livery_id": "Armée de l'air"}, f, allow_unicode=True, ...)
# bytes written: b"livery_id: Arm\xe9e de l'air\r\n"
# yaml.safe_load(open(tmp, encoding="utf-8").read()) -> UnicodeDecodeError
```

What the mission maker sees: the extraction reports success, and the next command — a build, an
injection, or a second `--merge` extraction — dies on a `UnicodeDecodeError` naming a byte offset.
`_merge_into` catches it and calls `logger.error`, which aborts (see the `logger-error-aborts`
measurement), so a `--merge` run refuses to do anything at all.

## What to do

Pass `encoding="utf-8"` at line 1531. Check the rest of the worker for the same asymmetry — any
`open(..., "w")` or `write_text` without an explicit encoding — and fix those too.

Do **not** drop `allow_unicode=True`: escaping the accents would keep the file readable but make the
liveries unreadable to a human editing the catalogue by hand, which is the documented workflow.

## Definition of Done

- A test writes a structure holding an accented livery through `_write_structure` and reads it back
  through `AircraftGroupsValidator.load` (or `load_yaml_data`) — it must fail on the current code.
- A test asserts the bytes on disk are UTF-8, so the fix cannot regress to the locale default by
  someone dropping the argument.
- No other unencoded write remains in `aircrafts_injector_worker.py`.
