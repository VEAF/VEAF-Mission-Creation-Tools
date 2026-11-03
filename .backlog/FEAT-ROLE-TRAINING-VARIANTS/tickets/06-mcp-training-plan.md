# 06 — MCP: propose and write the training plan

Status: ✅ done

Two actions, so that "build the training versions too" works on a mission Claude has just made as on an existing one.

- `propose_training_plan(mission_path)` — a **draft** `training:` block, from what the data can tell: AI fighter flights of the enemy coalition and on-demand CAPs → `enemy_cap`; QRA definitions → `qra`; long-range SAM types from the units database → `sam_lr`; combat zones → `a2g_target`; other SAMs inside or near an A2G zone → `sam_threat`.
  Everything is proposed **as placed**: only the briefing can say what is vague, and the action does not read prose.
  Each proposal says why it was made (the type, the module), so the reviewer can overrule it.
- `set_training_plan(mission_path, training)` — writes the block into `mission.yaml`, comments preserved, backed up first, refused when ticket 01's validation fails.

Both are thin handlers over the worker of ticket 01 (CLAUDE.md, layers): no CLI command, since a mission maker without an AI writes the block by hand.

## Done when

- On a fixture mission, the draft classifies an enemy CAP flight, a QRA, an SA-10, a combat zone and the SA-6 protecting it as the PRD's table expects.
- `set_training_plan` round-trips: what it writes, `validate_mission` accepts and the build turns into the five `.miz`.
- The mission prompts (`new-objective-mission.*.md`, and the authoring guide) tell Claude, once the briefing is written: offer the training versions; call `propose_training_plan`; for each element the briefing describes vaguely, move it to `randomize` with a pool of the same role (an SA-8 among short-range SAMs, a tank among armour); show the user the plan before writing it.
- The action catalogue documentation is updated in the same change (MCP catalogue lockstep).
