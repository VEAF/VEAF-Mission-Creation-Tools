# Lot FIX-TEMPLATE-SLOTS-VISIBLE — injected aircraft templates pollute the multiplayer slot list

Status: ✅ done

**Goal**: Aircraft templates injected by the tool (both the `veafSpawn-` spawnable groups and the `dynSpawnTemplate` dynamic-slot templates) carry `skill: Client` units, so they show up as **selectable slots** in the multiplayer briefing slot table (Tripack's screenshot: a long list of "… Template" slots). The injector already emits `hidden: true` (map only) and `lateActivation: true`, but **neither `hiddenOnPlanner`** (the DCS group flag that removes a group from the briefing slot list — already used 474× on the mission's own groups in Tripack's `.miz`) **nor a slot password**. So players can pick a template slot by mistake. The injector (`aircrafts_injector_worker.py`) handles no such field today. Fix the injection so templates no longer appear as pickable slots; lockstep defaults + doc + `test/python/`.

**Decided (David) — both (a)+(b)**: on injected template groups, set **(a)** `hiddenOnPlanner: true` (and `hiddenOnMFD: true`) so they vanish from the briefing slot list, **and** **(b)** a slot **password** so they are locked even if a slot is reached another way (defence in depth). Password value is an implementation detail (e.g. a fixed non-published constant). Must confirm neither flag nor the password disturbs dynamic-slot spawning, which references the template by name.

**Branch**: `fix/template-slots-visible` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-TEMPLATE-SLOTS-VISIBLE-001 | On injected aircraft templates (spawnable + dynamic-slot), emit both `hiddenOnPlanner: true` (+ `hiddenOnMFD: true`) and a slot password. Verify dynamic-slot spawning still works and the templates are gone from the briefing slot table. Lockstep defaults + doc; add an injector test asserting both the flags and the password are emitted on template groups. | `aircrafts_injector/aircrafts_injector_worker.py`, default templates, `doc/`, `test/python/` | fix | ✅ (#503) |
