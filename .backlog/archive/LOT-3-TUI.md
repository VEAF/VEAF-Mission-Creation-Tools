# Lot 3 — TUI: InquirerPy interactive mode

Status: ✅ done

**Goal**: `veaf-tools` with no arguments opens a guided interactive mode instead of showing help.
**Branch**: `feature/tui-interactive` → PR → `develop`
**Depends on**: Lot 1 (quality gate), Lot 2 TOOL-002 (VEAF_HOME for preferences)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| FEAT-001 | InquirerPy interactive mode when no argument is given | feat | 60 min | — | [x] |
| FEAT-002 | Persist preferences in `~/.veaf/preferences.json` | feat | 30 min | TOOL-002 | [x] |
| FEAT-003 | Pre-fill prompts from saved preferences | feat | 30 min | FEAT-002 | [x] |

**Raw total: 120 min → estimated (×1.15): ~140 min (~2h20)**

<details>
<summary>Ticket details</summary>

**FEAT-001 — Interactive mode**
Add `inquirerpy` to Poetry dependencies. If `len(sys.argv) == 1` (no arguments): show a fuzzy command selector (all 11 commands with descriptions), then prompts for the required parameters of the selected command. Reuse the same validators as the typer CLI to ensure consistency.

**FEAT-002 — Preference persistence**
JSON structure in `~/.veaf/preferences.json`:
```json
{
  "last_command": "build",
  "build": { "mission_folder": "...", "output": "..." },
  "inject-weather": { "mission": "...", "config": "..." }
}
```
Read via `veaf_libs` on interactive mode startup, written after each successful run.

**FEAT-003 — Pre-fill from preferences**
On interactive mode launch, read `preferences.json` and inject the last-used values as `default` in the InquirerPy prompts for the selected command. The user can modify them or confirm directly.

</details>
