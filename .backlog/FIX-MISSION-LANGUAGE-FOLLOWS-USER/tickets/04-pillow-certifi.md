# 04 — Pillow 13 and certifi 2026.10.19

Status: ✅ done

Asked by David before the 6.31.3 release, 2026-10-22: the open Dependabot alerts, in this PR.

- Pillow 12.3.0 → 13.0.0 (`pyproject.toml` `>=13.0,<14`): 14 alerts, one critical (heap overflow in `ImagingJpegDecode`), nine high. Dependabot's own PR #1164 is superseded by this one.
- certifi 2026.4.22 → 2026.10.19: one critical alert, emSign root CAs whose intermediate keys were compromised; no Dependabot PR existed. The tools use it for every download (self-update, terrain data, map tiles).

`poetry.lock` changes those two packages only (measured: the only `version` lines in its diff).

Done when: the full Python suite and the CI pass on the new versions, and the Dependabot alerts close.
