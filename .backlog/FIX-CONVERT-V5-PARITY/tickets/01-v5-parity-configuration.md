# 01 — Conversion writes a v5-parity configuration

Status: ⬜ ready

Issue: [#1300](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1300).

A converted mission gets v6 features its v5 version never had, and loses one v5 setting, with at best a detail line in the report.
The rule: the generated `mission.yaml` reproduces the v5 behaviour, and every v6 feature left off is a visible line the mission maker can flip.

- **`silence_all`** — write `QRA: { …, silence_all: true }` as soon as `ToggleAllSilence(true)` is found, QRAs in YAML or not.
- **Community scripts** — decide AIEN (and any opt-out script other than CTLD, CSAR, SKYNET, STTS whose v5 loading is explicit) from what the v5 mission actually loaded, as MiST already is, not from the file's presence in `published/`. When that cannot be told, write `false` with a comment saying why. Same for `REMOTE`: `true` only when `missionConfig.lua` initializes `veafRemote`.
- **v6-only pipeline steps** — a "v5 parity" block in `pipeline:` turns off what the v5 mission did not have: dynamic slot templates and warehouses (unless the v5 mission had dynamic slots), the BULLSEYE waypoint, weather variants, kneeboard pages. Each line carries a comment naming the feature. Do not write an empty `dynamic-slot-templates.yaml` nor a default `warehouses.yaml` for such a mission.
- **`DO_NOT_EXPORT_JSON_FILES`** — when the v5 mission set it, write `module_settings: veaf.DO_NOT_EXPORT_JSON_FILES: true`; otherwise leave the commented line.
- **`mission.language`** — always written, from the v5 mission when it tells, else from `--lang`.
- **Report** — `convert-v5-report.md` gets a section "Behaviour kept from v5" listing each line above, so the mission maker sees what to flip to get the v6 features.

Tests: a v5 fixture with `ToggleAllSilence(true)` and no YAML QRA → `silence_all: true`; a `published/` holding `AIEN.lua` that the mission never loads → `AIEN: false`; a fixture with no dynamic slots → the parity block, no empty templates file; `mission.language` always present. Each converted fixture then builds.

Done when: the tests pass; `src/defaults/mission-folder/mission.yaml` is unchanged (this is conversion output only), or updated in lockstep if a key it shows changes (§9 item 7); the conversion guide (FR and EN) explains the parity block.
