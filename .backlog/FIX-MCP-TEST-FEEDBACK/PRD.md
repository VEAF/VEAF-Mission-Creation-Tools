# Lot FIX-MCP-TEST-FEEDBACK — two real-usage fixes from the plugin test session

Status: ✅ done (PR pending → `feature/mcp-mission-editor`)

Branch: `fix/mcp-spawn-coalition-and-scaffold-tag` → PR → `feature/mcp-mission-editor`

## Context

Two issues surfaced while David drove a real mission through the plugin.

### 1. Assistant thought `-samLR` always spawns a red SAM

The assistant refused to use `-samLR` for a **blue** SAM site, claiming the alias yields a red one.
Verified at the source: `veafInterpreter.executeCommandOnUnit` runs a `#command` with
`unit:getCoalition()` (`veafInterpreter.lua:85`; `static:getCoalition()` for a static, l.94), so the
spawned asset takes the **fake-unit's own coalition** — a blue fake-unit → a blue SAM. `-samLR`'s
"random" (`addRandomParameter("defense", 4, 5)`) is the LR **battery type**, not the side.

Root cause of the belief: the skill said combat-zone "coalition is ignored" (true only for the
zone's geometric **capture** of real groups) and never stated that a `#command` fake-unit spawns in
its own coalition — so the assistant filled the gap with "SAM = enemy = red".

### 2. `scaffold_mission` installed 6.9.2 → `prepare --theatre` exit 2

Scaffolding a Syria mission failed: `prepare` returned exit 2 and `src/mission` stayed empty.
The veaf-tools the scaffold installed into the folder was **6.9.2** (`published-latest`), which has
no `--theatre` option — so `prepare --template … --theatre Syria` errored. `scaffold_mission`
defaulted its `tag` to `published-latest` and (unlike the plugin bootstrap) ignored
`VEAF_MCP_UPDATER_TAG`, so it installed the stale stable while the MCP itself ran the pre-release.

## Change

- `plugin/skills/veaf-mission-authoring/SKILL.md` — combat-zone section now states a `#command`
  fake-unit spawns in **its own coalition** (blue fake-unit → blue SAM; `-samLR` is not inherently
  red), and scopes "coalition is ignored" to geometric capture only.
- `veaf_mission_mcp/scaffold.py` — `tag` now defaults to `VEAF_MCP_UPDATER_TAG` (env) when set,
  else `published-latest`; an explicit `tag` argument still wins. So the folder's veaf-tools matches
  the version running the MCP (e.g. a pre-release under test), and `--theatre` is available.
- Tests: scaffold inherits the env tag / explicit tag wins.

## Out of Scope

- The underlying "the chantier isn't on `published-latest` yet" — resolved once it releases to
  master; the env-tag default makes testing work meanwhile.
