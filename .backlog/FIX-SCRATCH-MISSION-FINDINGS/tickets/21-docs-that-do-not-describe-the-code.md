# 21 — Two docs that do not describe the code

Status: ✅ done
Type: doc (+ a naming decision, point 1)
Files: `doc/mission-maker/scripts/veafCombatMission*.md`, `.prompts/new-open-training-mission*.md`,
possibly `veaf_libs/mission_template.py`

## Origin

GermanyCW-v6 rebuild of 2026-09-24.

## Measured

1. **`cap_missions[]`: `default` and `activated` mean something else.** The doc says `default` =
   "Démarrer comme mission active par défaut" and `activated` = "Activer immédiatement au démarrage"
   (`veafCombatMission.md:103-104,130-131`, same in `.en.md`). The generator passes them as the 4th
   and 5th arguments of `addCapMission` (`lua_config_generator.py:759-761`), whose signature is
   `(missionName, missionDescription, missionBriefing, secured, radioMenuEnabled, …)`
   (`veafCombatMission.lua:1444-1452`): `default` is **`secured`**, `activated` is
   **`radioMenuEnabled`**. A maker setting `activated: false` to keep a CAP dormant removes its menu.
2. **The `standard` template does not turn on COMBATZONE and QRA.** They are in the tier
   (`mission_template.py:205-206`), but as `CONFIG` modules, which are emitted **commented** by design
   (`mission_template.py:11-13`). The Open Training prompt announces "`standard` — le cœur, plus zones
   de combat, QRA, …" (`.prompts/new-open-training-mission.fr.md:40`, same in `.en.md`). In practice
   `create_combat_zone` re-enables `modules.COMBATZONE` when it writes a zone
   (`composites.py`, `_append_combat_zone`), so the gap is the description, not a broken mission.

## What it is not

The third point reported — `veafCasMission.md`'s "Référence de difficulté" announcing SA-6 / SA-11 at
level 5 — is **already fixed** on develop by ticket 12 (#996): the table now shows what the escort
places, and a `MODERN` per-level table follows it. Not reopened.

## To decide

Point 1: correct the doc to what the keys do, or rename the keys (`secured`, `radio_menu`) with the
old names read as aliases — the names are what misleads.

## Done when

- `cap_missions[]` keys documented (FR/EN) as what they do, or renamed per the decision, with a test
  of the generated `addCapMission` arguments
- The prompt (FR/EN) says what `standard` really writes — or the template writes what the prompt says

## Outcome

Decided: the keys keep their names (a rename would break every `mission.yaml` that has them); the doc
says what they do. `default` = `secured` (Activate / Deactivate reserved to authorised pilots),
`activated` = `radioMenuEnabled` (the CAP shows in the F10 menu); neither starts the CAP, which is
created inactive (`veafCombatMission.lua:509`). `test_cap_missions_arguments.py` pins the generated
`addCapMission` arguments so the doc and the code cannot drift apart again. The Open Training prompt
(FR/EN) says `standard` writes COMBATZONE and QRA as commented examples that `create_combat_zone` /
`create_qra` turn on.
