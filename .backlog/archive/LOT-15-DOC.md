# Lot 15 — DOC: Restructuration et mise à jour de la documentation

Status: ✅ done

**Goal**: Éliminer les redondances, améliorer la navigation, créer des landing pages par audience, mettre à jour le contenu.
**Branch**: `doc/restructure-navigation` → PR → `develop-v6`

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| DOC-001 | Nouvelle nav mkdocs (retirer USER_GUIDE, déplacer Testing sous Developer) | chore | 10 min | — | ✅ |
| DOC-002 | Réécrire Home (`doc/README.md` + `.fr.md`) — accroche, Getting Started global, quick links | feat | 30 min | DOC-001 | ✅ |
| DOC-003 | Enrichir `pilot/README.md` + `.fr.md` — landing page + Quick Start pilote | feat | 25 min | DOC-001 | ✅ |
| DOC-004 | Enrichir `mission-maker/README.md` + `.fr.md` — landing page + Quick Start mission-maker | feat | 30 min | DOC-001 | ✅ |
| DOC-005 | Enrichir `developer/README.md` + `.fr.md` — landing page + Quick Start dev | feat | 25 min | DOC-001 | ✅ |
| DOC-006 | Réécrire `mission-maker/scripts/README.md` + `.fr.md` — hub multi-index (workflow / interaction / fréquence) | feat | 40 min | DOC-004 | ✅ |
| DOC-007 | Mettre à jour versions (6.0.5 → 6.1.0) dans tous les fichiers doc | chore | 15 min | — | ✅ |
| DOC-008 | Redistribuer contenu unique de USER_GUIDE.md dans pilot/GUIDE.md | feat | 30 min | DOC-003 | ✅ |
| DOC-009 | Supprimer USER_GUIDE.md | chore | 5 min | DOC-008 | ✅ |
| DOC-010 | Fixer liens morts vers USER_GUIDE.md | fix | 20 min | DOC-009 | ✅ |

**Raw total: 230 min → estimated (×1.15): ~265 min (~4h25)**

<details>
<summary>Decisions log</summary>

- **USER_GUIDE.md** : retirer de la nav (DOC-001), redistribuer contenu utile dans pilot/GUIDE.md (DOC-008), puis supprimer (DOC-009)
- **Getting Started** : global sur Home + Quick Start intégré dans chaque Overview par rôle
- **Pages Overview** : enrichir comme landing pages (pas les supprimer)
- **Scripts** : 3 index sur la page Overview scripts (par workflow, par interaction joueur, par fréquence d'usage) — la nav latérale garde la liste plate pour accès direct
- **Traductions FR** : maintenues en parallèle
- **Testing** : déplacé sous la section Developer
- **Ton** : technique et factuel

</details>

<details>
<summary>Target nav structure</summary>

```yaml
nav:
  - Home: README.md
  - Pilot Guide:
    - Overview: pilot/README.md
    - Full Guide: pilot/GUIDE.md
  - Mission Maker:
    - Overview: mission-maker/README.md
    - Guide: mission-maker/GUIDE.md
    - Migration Guide: mission-maker/MIGRATION_GUIDE.md
    - Scripts:
      - Overview: mission-maker/scripts/README.md
      - veafAirWaves: mission-maker/scripts/veafAirWaves.md
      - veafAirbases: mission-maker/scripts/veafAirbases.md
      - veafAssets: mission-maker/scripts/veafAssets.md
      - veafCarrierOperations: mission-maker/scripts/veafCarrierOperations.md
      - veafCasMission: mission-maker/scripts/veafCasMission.md
      - veafCombatZone: mission-maker/scripts/veafCombatZone.md
      - veafGrass: mission-maker/scripts/veafGrass.md
      - veafMissileGuardian: mission-maker/scripts/veafMissileGuardian.md
      - veafMove: mission-maker/scripts/veafMove.md
      - veafNamedPoints: mission-maker/scripts/veafNamedPoints.md
      - veafQraManager: mission-maker/scripts/veafQraManager.md
      - veafSanctuary: mission-maker/scripts/veafSanctuary.md
      - veafSecurity: mission-maker/scripts/veafSecurity.md
      - veafSkynetIadsHelper: mission-maker/scripts/veafSkynetIadsHelper.md
      - veafSpawn: mission-maker/scripts/veafSpawn.md
      - veafTransportMission: mission-maker/scripts/veafTransportMission.md
      - veafWeather: mission-maker/scripts/veafWeather.md
  - Developer:
    - Overview: developer/README.md
    - Guide: developer/GUIDE.md
    - Testing: TESTING.md
  - References:
    - Lua API Reference: LUA_API_REFERENCE.md
    - Tools CLI Reference: TOOLS_REFERENCE.md
    - Roadmap: ROADMAP.md
```

</details>
