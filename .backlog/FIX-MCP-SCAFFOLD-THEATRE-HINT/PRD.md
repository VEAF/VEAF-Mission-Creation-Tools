# Lot FIX-MCP-SCAFFOLD-THEATRE-HINT — steer the LLM to pass `theatre` to scaffold_mission

Status: ✅ done (PR pending → `feature/mcp-mission-editor`)

Branch: `fix/mcp-scaffold-theatre-hint` → PR → `feature/mcp-mission-editor`

## Context

Real-usage feedback (David, live MCP session on a Syria mission): the assistant called
`scaffold_mission` **without** `theatre="Syria"`, so `prepare` ran without `--theatre` and
`src/mission` was left empty (by design). The assistant then misdiagnosed this as a scaffold
*failure* and claimed — wrongly — that no `veaf-tools` command exists to lay down a blank map
(`prepare --theatre` does exactly that).

Same recurring pattern as the `#command` / `list_shortcuts` gaps: the capability exists, but the
LLM does not seize an **optional** parameter. The `veaf-mission-authoring` skill already tells it to
ask for and pass `theatre` — but the skill is not always loaded (it ships with the plugin), whereas
the **action description is always visible** to the calling LLM. So the fix is on the action's
prompt surface.

(Separately: the veaf-tools binary that the updater installs is the published release — currently
far behind this branch — so even a correct `theatre` call would have failed on the old binary. That
is being addressed by cutting a fresh dev-release from `feature/mcp-mission-editor`, out of scope
here.)

## Change

- `actions.py` — `scaffold_mission` action + `theatre` parameter descriptions now tell the LLM to
  pass `theatre` whenever the mission targets a supported DCS map, and to omit it only when the
  maker supplies their own `.miz`. The `theatre` parameter also gains an `enum` populated from
  `blank_mission.supported_theatres()` — the single source of truth — so the LLM sees the valid
  names directly and invalid ones fail fast (no hard-coded example list to drift; Sourcery).
- Skill left unchanged — it already steers correctly.
- **Binary bundling fix (collateral, found while adding the enum).** Three `veaf_libs/data` files
  read at runtime were missing from the PyInstaller bundle, so the whole map/geo/blank surface
  broke when the MCP ran from the shipped binary (only ever exercised in a source checkout):
  - `theatre-defaults.yaml` → `prepare --theatre` / `scaffold_mission(theatre=)` / blank mission;
  - `dcs-maps.yaml` → `resolve_coordinates` / `describe_map` / `geocode` (projection);
  - `theatre-bounds.yaml` → `geocode` (per-theatre bounding boxes).
  Added all three to `worker.py`'s `bundled_data` (same fix as `dcsUnits.yaml` in
  FEAT-MCP-ORACLE-COMMANDS). Without this, the enum above would also crash catalog construction in
  the binary. This is the real prerequisite for the dev-release to be usable.

## Out of Scope

- The stale-binary issue (updater installs the published release) — fixed by publishing a fresh
  dev-release, tracked separately.
