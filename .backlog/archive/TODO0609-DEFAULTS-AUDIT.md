# Lot TODO0609-DEFAULTS-AUDIT — Audit the defaults mission-folder for dead files

Status: ✅ done

**Goal**: `prepare` copies the whole `src/defaults/mission-folder/` tree into a new mission via `rglob` (`prepare.py:68`), so any leftover file ships to users. The aircraft YAML files are legitimate (see TODO0609-AIRCRAFT-INJECT). Audit the rest to confirm nothing else is dead weight. Covers todo-2026.06.09 item 12.

**Branch**: `chore/defaults-audit` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DEFAULTS-AUDIT-001 | Audit each file under `src/defaults/mission-folder/` for whether it is actually consumed at first build (candidates to verify: `src/presets.md`, `src/README-versions.md`, `src/options`). Report role + used/unused per file; remove or document anything genuinely dead. Exclude the aircraft YAML (owned by TODO0609-AIRCRAFT-INJECT). | `src/defaults/mission-folder/`, `doc/` | chore | ✅ |

**Audit result (DEFAULTS-AUDIT-001)**: the suspected dead files `src/presets.md` and `src/README-versions.md` are **no longer present** in the scaffold (already removed). Every remaining file is consumed at first build — none is dead:

| File | Role | Status |
|------|------|--------|
| `.gitignore` | Scaffolds the user repo to ignore generated/downloaded artifacts (`/published/`, `/build/`, `veaf*.exe`, `*.miz.bak`) | used (scaffold) |
| `mission.yaml` | Main build configuration (modules, identity, missions) | used |
| `src/options` | DCS options table injected into the `.miz` (`miz_tools.py` options injection) | used |
| `src/presets.yaml` | Radio presets — `presets` pipeline step | used |
| `src/spawnables.yaml` | Predefined spawnable groups — SPAWN module | used |
| `src/templates.yaml` | Aircraft-group templates — SPAWN module (owned by AIRCRAFT-INJECT) | used (excluded from this audit) |
| `src/versions.yaml` | Weather/time variants — `weather` pipeline step | used |
| `src/waypoints.yaml` | Bullseye / navigation points — `waypoints` pipeline step | used |
| `src/scripts/mission-script.lua` | User custom Lua, loaded after generated `veaf-config.lua` | used |
| `src/scripts/veafDynamicConfig.lua` | Dynamic script-loading config (dev/test live-reload) | used |

Conclusion: nothing to remove. The `doc/mission-maker/GUIDE` project-layout tree (FR/EN) was corrected to list every shipped default with its role, so the structure documentation now matches reality.
