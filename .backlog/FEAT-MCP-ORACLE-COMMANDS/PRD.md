# Lot FEAT-MCP-ORACLE-COMMANDS — expose VEAF `#command` aliases in the oracle + fix binary bundling

Status: ✅ done (PR #592, merged into `feature/mcp-mission-editor`)

Branch: `feat/mcp-oracle-shortcut-commands` → PR → `feature/mcp-mission-editor`

## Context

Real-usage feedback: when authoring a combat zone through the MCP, the LLM did **not** ground
itself in the oracle for spawn aliases. It wanted a long-range SAM, invented `-lrsam` (which does
not exist — the real alias is `-samLR`), then went digging through existing missions to reproduce
the pattern. Investigation found the root cause is **not** LLM indiscipline but two holes:

1. **Oracle content gap.** `list_shortcuts` reads `veaf-units.yaml` (the `veafUnits`
   unit/group aliases: `sa2`, `shilka`, …). But `veafShortcuts.buildDefaultList()` defines **128
   more aliases** — the high-level `#command` shortcuts (`-samLR`, `-samSR`, `-armor`, random
   convoys, `-arty1`, …) — that live **only** in `veafShortcuts.lua` and are exposed by no oracle
   action. A perfectly disciplined LLM calling `list_shortcuts("sam")` would still not find
   `-samLR` and would be forced to guess.

2. **Binary bundling gap (collateral).** `dcsUnits.yaml` is **not** in the `bundled_data` list of
   `veaf_build/worker.py`, so `list_unit_types` (the oracle action for picking a DCS unit type)
   raises `FileNotFoundError` when the MCP runs from the shipped binary (the plugin delivery
   mode). It was only ever exercised in dev (source), so the break was invisible. `veaf-units.yaml`
   **is** bundled, so `list_shortcuts` itself works in the binary.

## Decisions (with David)

- **Bundling strategy for the new aliases = option (a), the `lua_module_scanner` pattern.** The 128
  aliases live only in `veafShortcuts.lua`, which is not bundled in the veaf-tools binary. A scanner
  parses `buildDefaultList()`; in dev it scans the `.lua` live; at build time `worker.py` generates
  a gitignored `veaf-shortcuts.json` that is bundled via `--add-data`. Exactly how
  `veaf_modules_list.json` / `lua_module_scanner` already work — single source of truth (the
  `.lua`), no committed generated artifact, no drift possible. (Rejected option (b): a committed
  derived YAML guarded by a freshness test — `veaf-units.yaml` is a *hand-maintained source of
  truth*, our aliases are a *derived* artifact; committing a derivative invites drift.)
- **New oracle block name = `commands`** (separate from `units`/`groups`): different semantics — a
  `#command` shortcut, not a `_spawn` unit/group.
- **Fold the binary-bundling fix (hole 2) into this lot.** Same theme ("oracle actually reliable
  once delivered in the binary"); one PR. Without it the brain stays half-broken in prod even after
  the content fix.
- **Also tighten the skill** so it steers the LLM to `list_shortcuts` first for combat-zone content.

## Tickets

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-ORACLE-COMMANDS-001 | **Shortcut scanner**: `veaf_libs/veaf_shortcuts_scanner.py` parsing `veafShortcuts.buildDefaultList()` → alias list (`aliases`, `description`, `veafCommand`), excluding `setHidden(true)` aliases. Three-tier source (bundled JSON → pre-generated JSON → live `.lua` scan) + `generate_shortcuts_json()`, mirroring `lua_module_scanner`. Unit tests. | feat | ✅ |
| FEAT-MCP-ORACLE-COMMANDS-002 | **Oracle wiring**: `list_shortcuts` returns a 3rd block `commands: [{aliases, description, veafCommand}]` from the scanner, honouring the `name_contains` filter. Tests assert `list_shortcuts("sam")` surfaces `-samLR`/`-samSR`. | feat | ✅ |
| FEAT-MCP-ORACLE-COMMANDS-003 | **Build bundling**: `worker.py` generates `veaf-shortcuts.json` before compilation and adds it to `bundled_data`; **also add the missing `dcsUnits.yaml`** to `bundled_data`. Gitignore the generated JSON. | fix | ✅ |
| FEAT-MCP-ORACLE-COMMANDS-004 | **Skill update**: `veaf-mission-authoring` SKILL.md — state that `list_shortcuts` also covers `#command` shortcuts, and steer to it first for combat-zone content. | docs | ✅ |

## Out of Scope

- Refactoring `veafShortcuts.lua` or the alias catalogue itself (content unchanged).
- Any other missing-from-binary data beyond `dcsUnits.yaml` (none found; `veaf-units.yaml`,
  `dcs-countries.yaml`, `airdromes.yaml`, `airfield-frequencies.yaml` are all bundled).
