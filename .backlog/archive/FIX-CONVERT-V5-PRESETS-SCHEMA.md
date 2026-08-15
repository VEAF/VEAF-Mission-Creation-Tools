# Lot FIX-CONVERT-V5-PRESETS-SCHEMA — a v5 presets.yaml survives conversion, then kills the build

Status: ✅ done — 2026-08-10

**Goal**: converting the repository's own demo mission to v6 — to give the smoke harness a mission
built from *current* sources — reported success. The build then produced the `.miz` and died on the
next pipeline step:

```
Pipeline : préréglages radio (presets.yaml)
Error loading presets from …/src/presets.yaml: 'dict' object has no attribute 'lower'
```

| # | Ticket | Status |
|---|--------|--------|
| 01 | Say what is wrong instead of dying on `.lower()` | ✅ |
| 02 | Detect and convert a v5-schema `presets.yaml` | ✅ |

## Why the converter left the file alone

The v5 demo already had a `src/presets.yaml`, and its schema nests the coalitions **one level deeper**
than v6 does:

```yaml
presets_assignments:          # v5, with the extra level
  coalitions:
    blue:
      plane: {all: modern_blue}

presets_assignments:          # v6
  blue:
    plane: {all: modern_blue}
```

`V6_PIPELINE_CANDIDATES` declares `src/presets.yaml` as the **target** the converter writes when it
generates presets from a v5 `settings.lua`. Finding a file already sitting there, it left it alone: the
file passed for converted because it was **in the right place and in the right file format** — while
its *schema* is the one thing that changed.

The vocabulary for this already existed. `_CLEANUP_SRC_KNOWN` lists `presets.v5.yaml` beside
`presets.yaml`, so "presets at the old schema" was a known concept. Nothing detected that a file
*named* `presets.yaml` held that content.

## And the failure told the mission maker nothing

`'dict' object has no attribute 'lower'` names neither the file, nor the key, nor what to do about it.
The error now names both, so whoever has to fix it can.

## Not the converter's fault, said explicitly

Worth recording because the first reading of the symptom blamed `convert-v5` for corrupting the file.
It had not touched it — that was the defect.
