# Lot FIX-MCP-SCAFFOLD-THEATRE-HINT — steer the LLM to pass `theatre` to scaffold_mission

Status: ✅ done (PR pending → `feature/mcp-mission-editor`)

Branch: `fix/mcp-scaffold-theatre-hint` → PR → `feature/mcp-mission-editor`

## Context

Real-usage feedback (David, live MCP session on a Syria mission): the assistant called
`scaffold_mission` **without** `theatre="Syria"`, so `prepare` ran without `--theatre` and
`src/mission` was left empty (by design). The assistant then mis-diagnosed this as a scaffold
*failure* and claimed — wrongly — that no `veaf-tools` command exists to lay down a blank map
(`prepare --theatre` does exactly that).

Same recurring pattern as the `#command` / `list_shortcuts` gaps: the capability exists, but the
LLM does not seize an **optional** parameter. The `veaf-mission-authoring` skill already tells it to
ask for and pass `theatre` — but the skill is not always loaded (it ships with the plugin), whereas
the **action description is always visible** to the calling LLM. So the fix is on the action's
prompt surface.

(Separately: the veaf-tools the updater installs is the published release — currently far behind
this branch — so even a correct `theatre` call would have failed on the old binary. That is being
addressed by cutting a fresh dev-release from `feature/mcp-mission-editor`, out of scope here.)

## Change

- `actions.py` — `scaffold_mission` action + `theatre` parameter descriptions now tell the LLM to
  pass `theatre` whenever the mission targets a known DCS map, and to omit it only when the maker
  supplies their own `.miz`. Prompt-surface only; no behaviour change.
- Skill left unchanged — it already steers correctly.

## Out of Scope

- The stale-binary issue (updater installs the published release) — fixed by publishing a fresh
  dev-release, tracked separately.
