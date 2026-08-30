# CHORE-DROP-HERCULES-SCRIPT — remove the Hercules Cargo script, keep the aircraft

Status: ✅ done — 2026-08-28

Origin: David, 2026-08-28, while `DROP-MIST` ticket 08 was counting which community scripts still need
MiST — *"hercules cargo : je ne crois pas que ça soit utilisé en fait"*. Checked, and he is right.

## Two different things called Hercules

This lot removes **one** of them. Saying which matters, because the names collide:

| Thing | Fate |
|---|---|
| **The C-130 mod** — `third_party_mods.json`, `group_insertion.py`, the Foothold convert profiles | **kept**, untouched |
| **CTLD's Hercules transport profile** — crates, troops, `useNativeDcsCargoSystem`, `maxTroopsOnboard: 30` | **kept**, and it is the reason the script is redundant |
| **`Hercules_Cargo.lua`** — the community script | **removed** |

The C-130 keeps flying and keeps carrying. What goes is a second, competing implementation of its
cargo handling.

## Why it can go

**Nothing enables it.** `HERCULES: false` in every `mission.yaml` in the repository — the demo mission,
the smoke-test mission, `verify-mission-a`, `verify-mission-c` — and in the shipped default at
`src/defaults/mission-folder/mission.yaml`. David confirms no VEAF mission uses it.

**CTLD already covers it.** `CTLD.lua` carries a full `Hercules:` transport profile: crate and troop
limits, loadable vehicle lists per coalition, `convertNativeLoadToCTLD`, `canParachuteDrop`. CTLD is
enabled where transport matters, so the capability is not lost with the script.

**It is third-party and unowned.** Its header — *"Hercules Cargo Drop Events by Anubis Yinepu … will
only work for the Herculus mod by Anubis"* — and no VEAF fork behind it, unlike CSAR and Skynet.

**It costs MiST.** Three real calls (`mist.utils.makeVec`, `mist.Logger`), which is three fewer reasons
to keep injecting MiST once `DROP-MIST` ticket 08 gets to the question.

## What happens to a mission that says `HERCULES: true`

**Measured, not assumed** — this is a breaking change for anyone outside the repository, so what it
breaks into matters.

`mission_builder_worker.py:793`: an id that is not in the community script list produces
`logger.warning(t("builder.unknown_community_script", id=...))` and is skipped. The build **succeeds**.
The key exists in both `en.json` and `fr.json`, so the message reads properly rather than printing a
raw key.

So the failure mode is a warning in a successful build — not silent, but easy to miss. Given that CTLD
covers the capability, the practical loss for such a mission is nil. **`RELEASE_NOTES.md` says so
anyway**: a mission maker should not have to deduce it from a warning.

## What to remove

| File | What |
|---|---|
| `src/scripts/community/Hercules_Cargo.lua` | the file, 39 KB |
| `src/python/veaf-tools/mission_tools/mission_constants.py` | the `{"id": "hercules", …}` entry |
| `src/python/veaf-tools/veaf_libs/mission_template.py` | `Module("HERCULES", FEATURE, "Community", tiers={"full"})` |
| `src/defaults/mission-folder/mission.yaml` | the `HERCULES: false` line |
| the repository's four test `mission.yaml` | the same line |
| `doc/MISSION_YAML_REFERENCE.md` / `.en.md` | the module table row |

Leave alone: `third_party_mods.json`, `group_insertion.py`, CTLD's profile, and the `CHANGELOG` /
`CONTEXT` mentions, which are history.

**Correction, found while doing it**: the Foothold convert profiles were listed here as "leave alone",
and they are not. Both name `hercules` in `disabled_community_scripts` — the list of VEAF scripts a
Foothold mission turns off because it ships its own. With the script gone, that entry becomes an id
nothing recognises, and every Foothold conversion would log *"Unknown community script id hercules"*.
Removed from both, and from the three Python tests that asserted the list's contents.

## Definition of done

- [x] The script and its registry entries are gone. **Two more were found while doing it**: the
      `disabled_community_scripts` list of both Foothold convert profiles named it, which would have
      logged *"unknown community script id"* on every Foothold conversion
- [x] A generated mission carries no `Hercules_Cargo.lua` — verified by unzipping a built `.miz`, not
      by reading the yaml
- [x] The Python suite passes (82.22 % coverage, gate 81); `ruff`, `ruff format` and `mypy` clean
- [x] `doc/` updated in both languages, `docs-check` clean
- [x] Stated in `CHANGELOG.md`, naming CTLD as what covers the capability and the C-130 mod as
      untouched. `RELEASE_NOTES.md` is written at release time, not per PR
- [x] `CHANGELOG.md` entry under `[Unreleased]`
