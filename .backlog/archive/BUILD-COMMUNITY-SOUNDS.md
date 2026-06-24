# Lot BUILD-COMMUNITY-SOUNDS — Build owns CTLD/CSAR sound preloading

Status: ✅ done

**Goal**: Make the build responsible for the community-script sound assets, so a mission does not have to carry them by hand. Today the `.ogg` files (CTLD: `beacon.ogg`, `beaconsilent.ogg`, `radiobeep.ogg`; CSAR: `CSAR.ogg`, `csar-beacon.ogg`) live only in the mission's own `src/mission/l10n/DEFAULT/` and are registered by a hand-made v5 `out_sound` trigger. `TRIGGERS-VERIFY-004` only *removes* that trigger when both modules are off; this lot covers the *add* side (David: "ajouter si CTLD ou CSAR enabled" + "du coup oui" the build should package the sounds itself).

**Resolved design** (David: "fichiers seuls"): CTLD/CSAR play their sounds **by filename** at runtime (`outSoundForCoalition("beacon.ogg")`, `outSoundForGroup("l10n/DEFAULT/CSAR.ogg")`), so the v5 `out_sound` trigger and the `mapResource` registration are **not** needed — packaging the `.ogg` in `l10n/DEFAULT/` is sufficient. Empirically confirmed the exact sound set per module:
- CTLD: `beacon.ogg`, `beaconsilent.ogg`, `radiobeep.ogg`
- CSAR: `beacon.ogg` (shared), `CSAR.ogg`

`csar-beacon.ogg` is not referenced anywhere and was dropped from the mapping. `radiobeep.ogg` (JTAC fallback beep, CTLD only) is **not redistributed by upstream** and is left to the mission maker — the build warns when an enabled module's required sound is shipped by neither the tools nor the mission. Assets flow into `published.zip` automatically (the release packager already includes all of `src/scripts/community/**`).

**Branch**: `feat/build-community-sounds` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| BUILD-COMMUNITY-SOUNDS-001 | Ship the CTLD/CSAR sound assets (`beacon.ogg`, `beaconsilent.ogg`, `CSAR.ogg`) under `src/scripts/community/sounds/` and inject the ones a mission is missing into `l10n/DEFAULT/` when CTLD or CSAR is enabled (mission-provided sounds win; nothing when both off; warn on a required sound shipped by neither tool nor mission). Files-only — no `mapResource` entry, no `out_sound` trigger. | `mission_builder/mission_builder_worker.py`, `mission_tools/mission_constants.py`, `src/scripts/community/sounds/`, `test/python/` | feat | ✅ |
| BUILD-COMMUNITY-SOUNDS-002 | Add `radiobeep.ogg` (JTAC fallback beep) to the shipped assets. **Done**: David provided a redistributable `radio-beep.ogg`; shipped as `src/scripts/community/sounds/radiobeep.ogg`, auto-injected for CTLD (mapping already required it); consistency test added. | `src/scripts/community/sounds/`, `test/python/` | feat | ✅ (#505) |
