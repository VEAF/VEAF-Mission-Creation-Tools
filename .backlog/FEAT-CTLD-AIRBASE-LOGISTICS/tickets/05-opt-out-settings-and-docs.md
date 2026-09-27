---
Status: 🔄 in-progress
---

# 05 — The opt-out, the three settings, and the documentation

**Blocked by:** 01 — the flag has to gate something that exists. Ships last so the documentation
describes what was built rather than what was intended.

## What it delivers

A mission maker who wants none of this says so in `mission.yaml`, in plain sight, and the three numbers
this lot introduced are his to change without editing Lua. The documentation says what an airfield
logistic zone is, when it opens and closes, and why a field can be registered and still read
*"Aucune logistique à portée"* 400 m from the stand.

## The one choice left, and it is David's

Where the opt-out key lives. Both work; they cost differently.

1. **`modules.CTLD.manage_airbase_logistics`** *(recommended)* — the sibling of `manage_logistics` from
   FEAT-CTLD-AUTO-LOGISTICS, so a maker reading his CTLD block sees both logistics flags together.
   Cost: `manage_logistics` is consumed by the **builder** (`_build_ctld_user_config` merges
   `ctld-config.yaml` on the way into the `.miz`), while this one is consumed by **VEAF Lua at runtime**,
   so the generator's CTLD branch has to emit it into `veaf-config.lua` — a new emission path, plus the
   validator and the scaffold.
2. **`settings:` keys** (`lua_config_generator.py:12` — *"arbitrary `veaf.config.XXX = value`"*) — zero
   new plumbing, straight to `veaf.config`, and the three numbers want to live there anyway. Cost: the
   flag sits away from the CTLD block it belongs to, which is exactly the invisibility
   FEAT-CTLD-AUTO-LOGISTICS ticket 01 was opened for — *"a maker who never sees the key cannot know the
   behaviour exists"*.

Whichever is chosen, the scaffold must **emit it** when CTLD is enabled, with a comment saying what it
does, and the disabled form must show the same shape so the key is discoverable before CTLD is switched
on.

## Do

- The flag, default **true**, and the three settings beside it: the zone radius (**250 m**), the
  occupation radius (**2000 m**) and the tick (**30 s**). None of the three is a constant at its call
  site once this ticket lands — 01, 02 and 03 each leave a module-level local to be replaced here.
- `src/defaults/mission-folder/mission.yaml` carries the same keys. The defaults file is a **lockstep**
  obligation (CLAUDE.md §9.7): the shipped default must match what the generator produces, in the same
  lot, and a test already compares the two — keep it green.
- `yaml_validator.py`: accept the keys, reject a non-boolean or a non-number with the same shape of
  message the neighbouring checks use. Do **not** touch the `settings:` rejection.
- With the flag off: nothing registers, no tick is scheduled, no circle is drawn, and the log says the
  feature was **asked to stay off** — not that no airfields were found. The two read the same to a maker
  debugging a mission and only one of them is true.
- Rewrite the documentation, in **both** languages (`doc/` and `doc/mission-maker/` are `.md` + `.en.md`,
  and `docs-check.yml` gates the pair):
  - `doc/MISSION_YAML_REFERENCE.md` + `.en.md`: the new key and the three settings.
  - `doc/mission-maker/GUIDE.md` + `.en.md`, CTLD section, next to what `manage_logistics` already says:
    airfields are logistic zones now, the two classes, the two minutes, the 30 s tick, and the fact that
    occupation counts **ground units** — so a transport landing on a captured field does not open it.
  - The gap David accepted on 2026-09-27, written down rather than discovered in flight: one 250 m zone
    per airfield, centred on the stand nearest the centroid, so on a spread apron an aircraft parked
    beyond 250 m reads *"Aucune logistique à portée"* at an active field — and the radius is the setting
    to raise.
- Amend **ADR 0016** (`docs/adr/0016-ctld2-sidecar-configuration.md`): VEAF now registers logistic zones
  CTLD did not discover, which is a further step past "the sidecar configuration is carried verbatim" —
  `manage_logistics` was the first. One paragraph, not a new ADR; 0018 (*undocumented DCS API
  dependency*) is worth a look while in there, since `Airbase:getParking()` is documented but its
  per-theatre contents are not.
- The messages 02 and 03 added get a line in whatever page lists in-game messages, if one does; ADR 0006
  (`lua-runtime-i18n`) is the rule they follow.

## Watch out

- Do not let the flag reach Lua as a **string**. `manage_logistics` is a boolean in YAML and the
  generated Lua must not become `veaf.config.X = "false"`, which is truthy in Lua and would silently
  enable the feature for every maker who typed the word instead of the value.
- The scaffold emission and the defaults file are the same change: emitting one without the other fails
  the lockstep test.
- A key nobody reads is worse than no key. Grep for the setting's name in `src/scripts/veaf/` before
  declaring this done, and add a Lua test that the module honours it — a Python test proving the YAML
  generates is not the same claim.

## Done when

- A mission scaffolded with CTLD enabled shows the flag and the three numbers in plain sight, with a
  comment saying what they do.
- A mission that sets the flag to `false` registers nothing, schedules nothing, draws nothing, and logs
  that it was asked not to.
- `manage_airbase_logistics: "yes"` (or the chosen key) fails validation with a readable message.
- The lockstep test, `docs-check`, `luacheck`, `stylua --check` and `poetry run test-lua
  --cov-fail-under 80.9` are green.
- ADR 0016 carries the paragraph, and the documentation states the accepted 250 m gap.
