# CHORE-VENDOR-CTLD-RC11 — take CTLD 2.0.0-rc11, which carries the fix for a live VEAF report

Status: ✅ done — 2026-09-18 (PR #962)

`published-v2.0.0-rc11` shipped on 2026-09-18. It closes the defect Zip reported from a live VEAF
multiplayer session the day before, plus two more found in its wake — all three fixed upstream and
merged the same day.

## Why this bump matters more than a routine sync

The report was a `dcs.log` from a mission built by these tools:

```
ERROR SCRIPTING: CTLDDCSEventBridge:onEvent handler error [onPlayerLeaveUnit / eventId=21]:
[string "l10n/DEFAULT/CTLD.lua"]:22698: attempt to call method 'getName' (a nil value)
```

Twice in one session, each a millisecond after DCS released a slot. `event.initiator` is not nil —
DCS hands over an object whose unit it has already released, so the method table is gone and a
`if not unit` guard covers nothing. The handler aborted on its third line, so the departing player
was never forgotten, his F10 menu never torn down, and the recycled-group-id protection never ran.

What rc11 brings ([#151](https://github.com/VEAF/CTLD/pull/151),
[#153](https://github.com/VEAF/CTLD/pull/153), [#154](https://github.com/VEAF/CTLD/pull/154)):

- the seven handlers that read a name straight off `event.initiator` now go through a helper that
  cannot raise, and the 30 s player scan — which could only ever *add* — forgets players whose slot
  is gone;
- a non-transport pilot keeps the CTLD functions that concern him. Recon works for any pilot, and
  with `addPlayerAircraftByType = false` he had no CTLD menu at all. Smoke and `List Beacons` open
  up, `Check Cargo` closes, `CTLDPlayerTracker` (never instantiated since April) is gone;
- `cancelPending` cancels the urgent debounce timer instead of only clearing its flag, so a
  cancelled rebuild can no longer land on the next occupant of a recycled group id.

## What was measured, not assumed

- **The download arrives in CRLF; the vendored copy is LF.** Converted before copying, as
  `CHORE-VENDORED-DRIFT-618` ticket 03 recorded for rc10. Real diff: **575 lines**, 278 insertions /
  297 deletions — consistent with three fixes and the ~150-line deletion of `CTLDPlayerTracker`.
- **The embedded configuration catalogue is byte-identical between rc10 and rc11** (21 968 bytes,
  same SHA1). It is extracted from the vendored file at build time (ADR 0016), so an added setting
  would have to reach the scaffold; none did, and §9.7's defaults lockstep does not apply.
- `ctld.VERSION` in the file reads `2.0.0-rc11`, and `test_vendored_pins_match_the_files.py` agrees
  with both the `pinned` field and the watch tag.
- `poetry run check-vendored` reports **all automatable pins up to date** — the drift the watch
  reported is cleared.
- `test_community_scripts_load.lua` — the gate `FIX-CTLD-RC9-LOAD-GATE` added after rc8 shipped
  dead — **loads** rc11 under the DCS mocks rather than parsing it. It passes, with the 47 other
  Lua suites.

## Definition of done

- `src/scripts/community/CTLD.lua` is the rc11 asset verbatim, in LF.
- `vendored.yaml` pins `2.0.0-rc11` and watches `published-v2.0.0-rc11`.
- The whole Lua suite green, the community load gate included; Python quality gate clean.
- `CHANGELOG.md` entry under `[Unreleased]`.
- No version bump — §9.5.

## Not claimed

The file has not been flown in DCS from this repository. The three defects were found from a real
`dcs.log` and fixed upstream with specs that reproduce each of them, and the evidence here stops at
"it loads and initialises under the mocks". Flying it is the natural next check, and it is the very
mission that produced the report.

## Out of scope

- Any other vendored artefact. `check-vendored` shows them all up to date.
- The `dev` floating pre-release, excluded from the watch by `tag_pattern` since ticket 02 of
  `CHORE-VENDORED-DRIFT-618`.
