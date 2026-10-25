# 09 — The opposition's skill

Status: 🧑 waiting-human

David: let the user choose the level of the enemy AI — for AI pilots, and for ground units if DCS allows it.

What exists: `add_air_group` takes `skill`; `set_unit_properties` sets `Average`/`Good`/`High`/`Excellent`/`Random` on any unit.
What does not: the objective prompt never asks; `add_group` writes `"skill": "Average"` for every unit it creates, and `create_combat_zone` goes through it; the `#veafInterpreter` batteries are spawned by the Lua with no skill (`veaf.addUnit` takes one but nothing calls it), so they get DCS's default, unknown.
DCS does carry a skill on vehicles (the Mission Editor shows it); what it changes for a SAM, under Skynet, is not measured.

To do:

1. The objective prompt (EN and FR), phase 1: one question, "Level of the opposition", the five values, `Random` meaning a mix; the chosen level goes on every red aircraft and ground unit the assistant creates.
2. `add_group` and `create_combat_zone`: a `skill` parameter (group-wide, per unit overridable), same values and refusals as `set_unit_properties`; `Average` stays the default.
3. Measure in DCS (David): the skill a `#veafInterpreter` battery ends up with (`Unit.getByName(...)` has no getter for it: read it from the mission table of a saved track or an editor reopen), and whether a ZSU-23-4 at Excellent shoots visibly better than at Average. Write the result as a known limitation (`kind: dcs`) if it surprises.

Not in this lot: a skill option of the interpreter (`#veafInterpreter["-sa3, skill excellent"]`), Lua — only if the measurement shows the default matters.

Done when: the question is in the prompt; `add_group` and `create_combat_zone` take `skill`, with tests; the measurement is reported here.

## Result

Done in the code: the objective prompt asks "The level of the opposition" (EN and FR); `add_group` and `create_combat_zone` take `skill`, group-wide with a per-unit override, refused on a static, `Average` by default (`AI_SKILLS`, now public in `set_unit_properties`).
Tests: `test_add_group_skill.py`.
Left: the measurement in DCS (David) — the skill a `#veafInterpreter` battery gets, and whether a ZSU-23-4 at Excellent shoots visibly better than at Average.
