# Backlog — VEAF Mission Creation Tools v6

## Calibration Table

| Lot | Estimated (min) | Actual (min) | Ratio | Note |
|-----|----------------|--------------|-------|------|
| *(no lot completed yet)* | | | | Initial factor: 1.15 |
| Lot 6 — BONUS | 210 | — | — | LUA-006 + TOOL-004 + LUA-007 |

## Legend

- **Effort**: estimated Copilot time in minutes (excludes user decisions and review)
- **Type**: `feat` / `fix` / `chore`
- **Status**: `⬜` to do · `🔄` in progress · `✅` done

> Completed lots (> 3 days ago) are moved to [backlog-archive.md](backlog-archive.md).

---

## Summary

| Lot | Estimate | Status |
|-----|----------|--------|
| Phase 0 — Restart | ~3h | [archived](backlog-archive.md) |
| Phase 0b — GitHub cleanup | ~25 min | ⬜ |
| Lot 1 — INFRA | ~4h15 | [archived](backlog-archive.md) |
| Lot 2 — CLI | ~2h35 | [archived](backlog-archive.md) |
| Lot 3 — TUI | ~2h20 | [archived](backlog-archive.md) |
| Lot 4 — LUA-CONFIG | ~6h | [archived](backlog-archive.md) |
| Lot 5 — RELEASE | ~1h30 | ⬜ |
| Lot 6 — BONUS | ~3h30 | [archived](backlog-archive.md) |
| Lot 7 — LUA FIXES | ~5h45 | [archived](backlog-archive.md) |
| Lot 8 — LUA-QUALITY | ~3h35 | [archived](backlog-archive.md) |
| Lot RC — v6.1.0 RC fixes | ~1h35 | [archived](backlog-archive.md) |
| Lot 9 — LUA-REFACTOR | ~11h30 | [archived](backlog-archive.md) |
| Lot 10 — YAML-CONFIG | ~14h | [archived](backlog-archive.md) |
| Lot 11 — I18N | ~7h10 | [archived](backlog-archive.md) |
| Lot 12 — QUALITY | ~16h35 | [archived](backlog-archive.md) |
| Lot 13 — DISCUSS | ~13h50 | [archived](backlog-archive.md) |
| Lot 14 — ARCH-COMMANDS | ~7h30 | [archived](backlog-archive.md) |
| Lot 15 — DOC | ~6h | [archived](backlog-archive.md) |
| Lot UPDATER-FIX | ~65 min | [archived](backlog-archive.md) |
| Lot 16 — LUA-COVERAGE | ~17h15 | [archived](backlog-archive.md) |
| Lot 17 — USER-CONFIG | ~3h | [archived](backlog-archive.md) |
| Lot 18 — VERSIONING | ~1h45 | [archived](backlog-archive.md) |
| Lot 19 — MIGRATOR | ~2h30 | [archived](backlog-archive.md) |
| Lot 20 — DEEPENING | ~7h | [archived](backlog-archive.md) |
| Lot 21 — TYPING | ~20 min | [archived](backlog-archive.md) |
| Lot 22 — TEST-LAYOUT | ~55 min | [archived](backlog-archive.md) |
| Lot 23 — DOC-YAML | ~8h20 | [archived](backlog-archive.md) |
| Lot 24 — DOC-REVIEW | ~2h45 | ⬜ (REV-002 en attente) |
| Lot 25 — EXT-YAML | ~2h | [archived](backlog-archive.md) |
| Lot FIX-SORT — LUADATA FIX | ~15 min | [archived](backlog-archive.md) |
| Lot 26 — IMC-FEEDBACK | ~2h40 | [archived](backlog-archive.md) |
| Lot FIX-BUNDLE — VEAFCOMMANDS MISSING | ~10 min | [archived](backlog-archive.md) |
| Lot FIX-ASSETS-NEWLINE — ASSETS newline in Lua string | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-WEATHER-ALIAS — missions.yaml + versions.yaml coexistence | ~25 min | [archived](backlog-archive.md) |
| Lot FIX-MISSIONCONFIG-BAK — supprimer extension .bak inutile | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-README-COPY — ne plus copier presets.md dans src/ | ~10 min | [archived](backlog-archive.md) |
| Lot FIX-AIRCRAFT-ORPHAN — alerte fichier orphelin manquante pour aircraft-templates.yaml | ~15 min | [archived](backlog-archive.md) |
| Lot DOC-DEV-MODE — documenter dev_mode + scripts_path | ~30 min | [archived](backlog-archive.md) |
| Lot FEAT-PROFILES — profils de build dans mission.yaml | ~3h | [archived](backlog-archive.md) |
| Lot FEAT-MODULE-UX — Catégories, modules obligatoires, dépendances | ~2h | [archived](backlog-archive.md) |
| Lot FEAT-GITIGNORE — Template `.gitignore` VEAF MCT dans les defaults | ~25 min | [archived](backlog-archive.md) |
| Lot FIX-OLDSCRIPTS — Détection fichiers .lua résiduels dans src/scripts/ | ~45 min | ✅ |
| **Total** | **~167h20** | |

*Initial calibration factor: 1.15 — recalculate after each completed lot.*

---

## Lot FIX-OLDSCRIPTS — Détection fichiers .lua résiduels dans src/scripts/

**Goal**: Détecter les fichiers `.lua` résiduels v5 dans `src/scripts/` d'une mission convertie et émettre un avertissement au build.

**Context**: Le bug original (`veafCommands nil`) a été résolu par Lot FIX-BUNDLE. Cause secondaire potentielle non traitée : des fichiers VEAF `.lua` v5 individuels encore présents dans `src/scripts/` pourraient être chargés via le glob `src/scripts/*.lua` et créer des conflits au runtime DCS. OLDSCRIPTS-002 peut être implémenté indépendamment de l'investigation.

**Branch**: `fix/oldscripts-detection` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| OLDSCRIPTS-000 | Investigation : reproduire le bug avec une vraie mission v5→v6 ; obtenir les logs DCS complets ; identifier le fichier responsable | — | chore | 15 min | ✅ (résolu — voir contexte) |
| OLDSCRIPTS-001 | Fix : selon le résultat de l'investigation, corriger la cause racine identifiée | TBD | fix | TBD | ✅ (résolu par FIX-BUNDLE) |
| OLDSCRIPTS-002 | Ajouter un warning si des fichiers `.lua` inattendus sont présents dans `src/scripts/` (i.e. non listés explicitement dans `get_mission_script_files()`) | `mission_tools/mission_constants.py` ou `mission_builder_worker.py` | fix | 15 min | ✅ |

**Raw total: ~45 min estimé (hors investigation)**

---

## Lot 24 — DOC-REVIEW: Klogg profile (REV-002)

**Goal**: Committer le profil Klogg VEAF dans le repo pour faciliter la lecture des logs DCS.

**Context**: Tous les autres tickets REV-* du Lot 24 sont archivés. REV-002 attend que l'utilisateur fournisse le fichier `.conf` Klogg.

**Branch**: `fix/doc-review-klogg` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| REV-002 | Committer le profil Klogg fourni par l'utilisateur dans `tools/klogg/veaf.conf` ; mettre à jour la section "Reading the log" dans `GUIDE.md` et `GUIDE.fr.md` pour pointer vers ce fichier | `tools/klogg/veaf.conf`, `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | chore | 20 min | ⬜ |

---

## Phase 0b — GitHub cleanup

Close issues identified during triage. **Verify each one before closing.**
Direct commits on `develop-v6` (no feature branch needed — no code change).

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| CLOSE-001 | Close WONTFIX issues: #55, #146, #147, #180, #193, #246 | chore | 15 min | ⬜ |
| CLOSE-002 | Close STALE issues: #9, #19, #41, #167 | chore | 10 min | ⬜ |

<details>
<summary>Issues to close</summary>

**WONTFIX — Already implemented or out of scope**

| # | Title | Reason |
|---|-------|--------|
| #55 | Faire un système de zone de combat dynamique | Already implemented → `veafCombatZone` |
| #146 | CTLD JTAC 9-line | External project (CTLD/Ciribob) |
| #147 | CTLD JTAC Ask for wind/speed correction | External project (CTLD/Ciribob) |
| #180 | AirWaves - forcer à rester dans la zone | Both tasks already checked ✅ in the issue |
| #193 | CTLD - gestion d'emport multiple de caisses | Requires upstream PR to CTLD, out of scope |
| #246 | CTLD - orientation des unités Patriot | CTLD external bug, out of scope |

**STALE — No activity, too vague, or superseded**

| # | Title | Reason |
|---|-------|--------|
| #9 | Marker command to build a transport mission interception | 2018, no activity since 2021, too vague |
| #19 | Idée - spawn facile avec inventaire des unités par coalition | 2020, informal idea, no spec |
| #41 | Tester spawn humains CASE 1 téléportés à la bonne position | 2021, vague, no activity |
| #167 | Tester gRPC | 2023 tech spike, no follow-up planned |

</details>

---

## Lot 5 — RELEASE: v6.1.0

**Goal**: Merge v6 to master and publish the official release.
**From**: `develop-v6` directly

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| REL-001 | Finalize `CHANGELOG.md` for v6.1.0 | chore | 20 min | Lots 1–4 | ⬜ |
| REL-002 | Write `RELEASE_NOTES.md` for v6.1.0 | chore | 20 min | REL-001 | ⬜ |
| REL-003 | Squash merge `develop-v6` → `master` | chore | 15 min | REL-002 | ⬜ |
| REL-004 | Tag `v6.1.0` + publish GitHub (`veaf-build publish`) | chore | 30 min | REL-003 | ⬜ |

**Estimated total: ~85 min (~1h30)**
