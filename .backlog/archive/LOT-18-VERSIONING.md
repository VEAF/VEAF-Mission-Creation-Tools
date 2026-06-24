# Lot 18 — VERSIONING: Single source of truth pour la version ✅

Status: ✅ done

**Goal**: Centraliser la version dans `pyproject.toml` et la propager automatiquement partout.

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| VER-001 | Supprimer les fallbacks version hardcodés ; générer `_version.py` depuis `veaf_build/worker.py` | `veaf_tools/app.py`, `veaf-tools-updater.py`, `veaf_build/worker.py` | chore | 30 min | ✅ |
| VER-002 | Métadonnées Windows EXE (FILE_VERSION/PRODUCT_VERSION) via PyInstaller `version_file.txt` | `veaf-tools.spec`, `veaf-tools-updater.spec`, `veaf_build/worker.py` | chore | 45 min | ✅ |
| VER-003 | Afficher la version dans `about` (`veaf-tools vX.Y.Z`) | `veaf_tools/commands/about.py`, `locales/en.json`, `locales/fr.json` | feat | 15 min | ✅ |

**Raw total: 90 min → ~105 min (~1h45)**
