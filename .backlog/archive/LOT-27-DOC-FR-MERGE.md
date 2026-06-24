# Lot 27 — DOC-FR-MERGE: French as default language + v5 content merge

Status: ✅ done

**Goal**: Switch French as the default MkDocs documentation language and enrich v6 pages with the missing conceptual content from the v5 documentation (written manually).

**Branch**: `feature/doc-fr-default-and-v5-merge` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| DOC-FR-001 | Rename `*.md` → `*.en.md` and `*.fr.md` → `*.md` (35 pairs) | `doc/**` | chore | 15 min | ✅ |
| DOC-FR-002 | Update `mkdocs.yml`: FR default, EN secondary | `mkdocs.yml` | chore | 10 min | ✅ |
| DOC-FR-003 | Merge v5 content → `veafQraManager.md` (FR + EN) | `doc/mission-maker/scripts/veafQraManager.*` | chore | 45 min | ✅ |
| DOC-FR-004 | Merge v5 content → `veafCombatZone.md` (FR + EN) | `doc/mission-maker/scripts/veafCombatZone.*` | chore | 45 min | ✅ |
| DOC-FR-005 | Merge v5 content → `veafAirWaves.md` (FR + EN) | `doc/mission-maker/scripts/veafAirWaves.*` | chore | 30 min | ✅ (v6 already complete) |
| DOC-FR-006 | Merge v5 content → `veafRadio.md` (FR + EN) | `doc/mission-maker/scripts/veafRadio.*` | chore | 20 min | ✅ |
| DOC-FR-007 | Merge v5 content → `veafSkynetIadsHelper.md` (FR + EN) | `doc/mission-maker/scripts/veafSkynetIadsHelper.*` | chore | 20 min | ✅ |
| DOC-FR-008 | Merge v5 content → `veafWeather.md` (FR + EN) | `doc/mission-maker/scripts/veafWeather.*` | chore | 20 min | ✅ |
| DOC-FR-009 | Check `presets.md` v5 and identify the v6 equivalent | TBD | chore | 15 min | ✅ (already in GUIDE.md) |
