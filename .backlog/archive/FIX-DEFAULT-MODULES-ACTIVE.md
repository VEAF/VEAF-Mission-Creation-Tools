# Lot FIX-DEFAULT-MODULES-ACTIVE — default mission.yaml ships an active modules block

Status: ✅ done

**Goal**: A freshly-scaffolded mission's default `mission.yaml` had **every** module commented out → building it activated no module → **no VEAF F10 menu** in game. Per David, the default must mirror `convert-v5`'s baseline so a fresh mission works out of the box. Active set chosen (option C minus MISSILEGUARDIAN).

**Branch**: `fix/default-mission-yaml-active-modules` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-DEFAULT-MODULES-ACTIVE-001 | Default `mission.yaml` ships an **active** `modules:` block: mandatory infrastructure (bare) + `SECURITY`/`RADIO`/`GROUNDAI`/`SPAWN`/`NAMEDPOINTS`/`MOVE`/`GRASS`/`WEATHER`/`REMOTE`/`AIRBASES`/`INTERPRETER: true`; community scripts `false`; config-requiring modules (`ASSETS`, `QRA`, `SHORTCUTS`, `SANCTUARY`, combat, …) as commented examples. Mirrors convert-v5 baseline (IMC2-007 lockstep). | `src/defaults/mission-folder/mission.yaml` | fix | ✅ |
