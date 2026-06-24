# Lot UPDATER-FIX — Séparation updater / prepare / workflow v5

Status: ✅ done

**Goal**: Corriger l'architecture updater → ne plus créer de fichiers `src/` par défaut. `prepare` est la commande dédiée pour initialiser un nouveau dossier. Supprimer `build.cmd` du toolkit v6. Corriger la doc MIGRATION_GUIDE (partir du dossier v5 existant, pas d'un dossier vide).
**Branch**: `feature/updater-no-src-defaults` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| UPDFIX-001 | Supprimer `src/build-scripts/build.cmd` (plus de `build.cmd` dans le toolkit v6) | `src/build-scripts/build.cmd` | chore | 5 min | ✅ |
| UPDFIX-002 | `veaf-tools-updater.py` — `_install_defaults()` n'installe plus rien dans `src/` ; affiche juste un message vers `veaf-tools prepare` au premier install | `src/python/veaf-tools/veaf-tools-updater.py` | fix | 15 min | ✅ |
| UPDFIX-003 | `prepare.py` — corriger la résolution de chemin (sans bloc `build_scripts`) | `src/python/veaf-tools/veaf_tools/commands/prepare.py` | fix | 20 min | ✅ |
| UPDFIX-004 | Doc `MIGRATION_GUIDE.md/.fr.md` — workflow v5 : partir du dossier existant, pas d'un dossier vide | `doc/mission-maker/MIGRATION_GUIDE.md`, `doc/mission-maker/MIGRATION_GUIDE.fr.md` | doc | 20 min | ✅ |
| UPDFIX-005 | Doc `GUIDE.md/.fr.md` — supprimer `build.cmd` de la structure de dossier | `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | doc | 5 min | ✅ |

**Estimated total: ~65 min**
