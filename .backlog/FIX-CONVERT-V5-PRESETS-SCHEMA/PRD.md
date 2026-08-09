# FIX-CONVERT-V5-PRESETS-SCHEMA — a v5 presets.yaml survives conversion, then kills the build

Status: ⬜ ready

## How it was found

Converting the repository's own demo mission to v6 on 2026-08-09, to give the smoke harness a
mission built from **current** sources. `convert-v5` reported success. The build then produced
the `.miz` and died on the next pipeline step:

```
Pipeline : préréglages radio (presets.yaml)
Error loading presets from …/src/presets.yaml: 'dict' object has no attribute 'lower'
AttributeError: 'dict' object has no attribute 'lower'
```

## The two defects, which are not equally bad

### 1 — the file was never converted, and nothing noticed

The v5 demo already had a `src/presets.yaml`. Its schema nests the coalitions one level deeper
than v6 does:

```yaml
# what the converted mission carries (v5 schema)   # what v6 expects
presets_assignments:                                presets_assignments:
  coalitions:            # <- the extra level         blue:
    blue:                                               plane: {all: modern_blue}
      plane: {all: modern_blue}                       red: …
```

`V6_PIPELINE_CANDIDATES` declares `src/presets.yaml` as the **target** the converter writes when
it generates presets from a v5 `settings.lua`. Finding a file already sitting there, it left it
alone. The file passed for converted because it was **in the right place and in the right file
format** — while its *schema* is the one thing that changed.

The vocabulary for this already exists: `_CLEANUP_SRC_KNOWN` lists `presets.v5.yaml` beside
`presets.yaml`, so "presets at the old schema" is a known concept. Nothing detects that a file
named `presets.yaml` holds that content.

### 2 — the failure message tells the mission maker nothing

```python
for unit_type, preset_definition_name in type_data.items():
    if preset_definition_name.lower() == "none":
```

A string is assumed, a dict arrives, and it dies on a missing method. The message names no file,
no key, and no expectation. This is the shape `SECREV-2` ticket 07 catalogues as *"malformed YAML
raises an unguarded exception"* (VMR-055 is the same defect in the spawn renderer) — and this one
is worse than the conversion gap, because it will greet anyone whose presets file is off by one
level, whatever the reason.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Say what is wrong instead of dying on `.lower()`](tickets/01-readable-presets-error.md) | ⬜ |
| 02 | [Detect and convert a v5-schema presets.yaml](tickets/02-convert-v5-schema.md) | ⬜ |

Ticket 01 first, deliberately: it is smaller, it helps every mission maker rather than only those
converting, and it turns ticket 02's bug into a legible one while ticket 02 is being written.

## Why it matters beyond the demo

Any mission converted from v5 that already had a `presets.yaml` carries this. The build **does**
produce the `.miz` before dying — so the failure looks like "presets are broken" rather than
"your mission never converted", and the `.miz` sitting in the folder makes it look like it worked.
