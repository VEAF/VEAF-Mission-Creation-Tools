# Lot SCAFFOLD — `veaf-tools new` (mission folder scaffolding)

Status: ✅ done

**Goal**: lower the entry cost for new mission makers by scaffolding a `mission.yaml` from a chosen module preset. **Decision (with David)**: `prepare` already copies the default scaffold, so **do not add a separate `new` command** — extend `prepare` with `--template`. Templates are coverage tiers, not per-module: `minimal` (infra + RADIO/SPAWN/SHORTCUTS/INTERPRETER), `standard` (everyday set), `full` (everything; config-heavy modules as commented examples), `custom` (interactive module pick). In all cases the generated `mission.yaml` reflects the chosen modules + adapted config defaults. `SECURITY` off by default everywhere; `GROUNDAI` excluded (unfinished); `TUM` only in `full`, commented + warning.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SCAFFOLD-001 | Data-driven module catalog + `mission.yaml` generator (`veaf_libs/mission_template.py`, single source of truth); `prepare --template minimal\|standard\|full\|custom` + `--list-templates` + interactive `custom` + next-steps guidance; localized FR/EN; tests (generator + CLI); maker-guide docs | `veaf_libs/mission_template.py`, `veaf_tools/commands/prepare.py`, locales, `test/python/`, `doc/`, `CHANGELOG.md` | feat | ✅ |
