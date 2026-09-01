# FIX-QRA-COMMANDS-AND-OFFSET — two ways a QRA config is accepted and then ignored

Status: ⬜ ready

Found 2026-09-01 while preparing the DCS session mission for release-gate item **R7**. Both defects
sit between `mission.yaml` and the runtime, and both are silent: nothing in the build says the
feature will not work.

They matter together because they explain each other. `FIX-AIRWAVES-COMMAND-EASTING` (#884) repaired a
command-driven QRA element that spawned on the theatre's central meridian, and its PRD asked an open
question — *why did nobody report this?* Because **the build refuses to produce such a mission**.

## 1. `validate` refuses a VEAF command in a QRA deploy list

```
✗ Le groupe '[0,0]-spawn shilka, country russia' déclaré dans QRA est absent de la mission
  — placez-le dans le Mission Editor, sinon la fonctionnalité échoue au runtime.
```

`collect_declared_groups` (`mission_builder/group_validation.py:76-84`) gathers every QRA
`simple_groups` and `groups_by_enemy_count` entry and checks each against the mission's group names.
A VEAF command is not a group name, so it is reported as missing and the build stops.

**But the runtime accepts exactly that form.** `veafQraCore` tests
`veaf.startsWith(groupNameOrCommand, "[")` and routes it to `veafInterpreter.execute` — the branch
#884 repaired. So the validator forbids a documented, working feature.

**Asymmetric, which is the tell**: `AIRWAVES` waves are **not** collected at all, so the same syntax
passes there. One module refuses it, its twin allows it, and neither is deliberate.

## 2. `respawn_default_offset` is accepted for a QRA and never emitted

`lua_config_generator.py:820` emits `:setRespawnDefaultOffset(x, y)` **only** inside the AirWaveZone
builder. The QRA builder never emits it, although `VeafQRACore:setRespawnDefaultOffset`
(`veafQraCore.lua:499`) exists and is what `FIX-WAVE-OFFSET-AXES` (#885) just repaired.

So a mission maker writing `respawn_default_offset: [0, 3000]` under a QRA definition gets no error,
no warning, and no offset. Verified on the session mission: the generated `veaf-config.lua` carries
`:setRespawnDefaultOffset(4000, -7000)` for the wave zone and nothing for the QRA declared beside it.

This is the same family as `FIX-CONVERT-V5-SILENT-LOSSES` — a key the generator swallows — and the
four keys that lot found were documented in the same pass. Worth checking whether other QRA keys go
the same way rather than fixing this one alone.

## Definition of done

- [ ] A VEAF command passes `validate` in a QRA deploy list, and a genuinely absent **group** is still
      reported — the check keeps its value
- [ ] The rule is shared with AIRWAVES rather than written twice: today one module collects and the
      other does not, and that difference is the defect
- [ ] `respawn_default_offset` reaches the generated Lua for a QRA, with a test asserting the emitted
      line and not the setter
- [ ] **Every QRA key of `mission.yaml` checked against what the generator emits** — enumerate, do not
      sample; that is what turned #884 from one site into two
- [ ] Both documented in the QRA reference, both languages

## Why it is worth doing before the next release

R7 of `DCS-SESSION-TODO.md` was written to exercise a command-driven QRA and had to fall back to an
editor group, because the build would not produce the mission. The repair shipped in #884 therefore
still has no in-game check on the QRA side.
