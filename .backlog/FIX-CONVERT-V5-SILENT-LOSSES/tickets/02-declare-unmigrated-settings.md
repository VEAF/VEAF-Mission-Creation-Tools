# 02 — Declare the settings that are not migrated

Status: ⬜ ready

Issues: [#725](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/725) (option 2),
[#723](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/723) (option 2) · Type: feat ·
Files: `mission_builder/config_migrator.py`, `mission_builder/v5_converter.py`

## Why this is the ticket that matters

`convert-v5` generates `mission-script.lua` from scratch and deletes `missionConfig.lua`
(`v5_converter.py:1144-1151`). No `warning` is emitted for a setting no extractor recognised —
**by construction, you cannot report what you do not see**. So the failure mode is a mission that
looks converted, behaves differently, and names nothing.

The information already exists on another path, which is the argument for doing this rather than
chasing keys one by one: the **migrated buffer** keeps unrecognised lines as commented-out code,
and the standalone `migrate-config` command writes it. `convert-v5` throws it away — the comment at
`v5_converter.py:1153-1158` says exactly that. We are not missing the data; we are discarding it on
the path everybody uses.

## The precedent to copy

`MigrationResult.callback_hints` (`config_migrator.py:92`) already models a **declared loss**:
Lua snippets for callbacks that must be set by hand, emitted into the generated file as
`-- [v6 migration] callbacks not migrated. Set them manually after init:` (`:1637`). `setOnWon` on
`airwave_zones` is handled this way today and nobody complains, because the author is told.

## What to do

In `pre_extract`, after the extractors have run, collect every remaining top-level assignment whose
target matches a known VEAF module table (`veaf*.`, `ctld.`, `csar.`) and that no extractor
consumed, into a `not_migrated` list on `MigrationResult`. Report it the way `callback_hints` is
reported:

- a `warning` naming each dropped setting (so it lands in `convert-v5-report.md`)
- a commented block in the generated `mission-script.lua`, carrying the **original line** so the
  author can paste it back

Do the same for builder-chain setters that no `_parse_*` maps to a key — that is #723's cheap half,
and it covers the seven ignored `combat_zones` setters before ticket 03 carries any of them.

## Two traps

- **Do not report what is deliberately not carried.** `getMissionEditorZoneName` (21 occurrences)
  is a getter used as a chain link, and the `ctld.*` / `csar.*` keys are already handled generically
  by `_extract_ctld_csar`. An exclusion list by name, with a comment per entry saying why — a net
  that cries wolf gets muted, and then it is worth nothing.
- **A silent no-op looks identical to a clean result.** Sharko's harnesses run two witnesses on
  every execution for exactly this reason. Do the same here: a test asserting a **known-dropped**
  key is reported, and one asserting an injected dummy key is *not* (it belongs to no VEAF table).

## Tests

- A `missionConfig.lua` carrying `veafSkynet.DelayForStartup = 150` produces a warning naming it and
  a line in the generated Lua
- A key an extractor *does* consume (`veaf.config.MISSION_NAME`) is **not** reported — the witness
  that proves the net discriminates
- An unknown non-VEAF assignment is ignored
- `getMissionEditorZoneName` in a chain is not reported
- The generated `mission-script.lua` is no longer a 349-byte header when something was dropped
