# Lot YAML-UX — Simplification syntaxe mission.yaml

Status: ✅ done

**Goal**: Rendre `mission.yaml` lisible et modifiable par des utilisateurs non-informaticiens. Réduire les pièges syntaxiques (deux mots-clés pour la même chose, `{}`, `[]` inline, guillemets inconsistants). Unifier `lua_modules` et `community_scripts` en un seul bloc `modules:`.

**Principes directeurs**:
- Un seul style par construction YAML
- Même syntaxe pour les modules VEAF et les scripts communautaires
- Guillemets uniquement quand nécessaire, règle documentée
- Les listes toujours en style bloc (`-`), jamais inline `[]`
- `true`/`false` seuls quand pas de config supplémentaire, bloc `enabled:` sinon

**Dépendances**: UX-001 → UX-002 → UX-003 (dans cet ordre). UX-004/005/006 indépendants.

**Branch**: `feature/yaml-ux` → PR → `develop`

| # | Ticket | Description | Files | Type | Effort | Status |
|---|--------|-------------|-------|------|--------|--------|
| YAML-UX-001 | `MODULE: {}` → `MODULE:` (null = module obligatoire actif, plus lisible) | Remplacer la génération et le parsing de `{}` pour les modules obligatoires — `null` YAML est équivalent et moins cryptique | `lua_config_generator.py`, `mission_builder_worker.py`, template `mission.yaml`, `config_migrator.py` | feat | 45 min | ✅ |
| YAML-UX-002 | Unifier `enable`/`enabled` → `enabled` partout | `lua_modules` utilise `enable`, `community_scripts` et `dcs_bridge` utilisent `enabled` — standardiser sur `enabled`, lire l'ancienne clé avec warning de dépréciation | `lua_config_generator.py`, `mission_builder_worker.py`, `v5_converter.py`, docs, template | feat | 1h | ✅ |
| YAML-UX-003 | Fusionner `lua_modules` + `community_scripts` → `modules:` avec syntaxe unifiée | Un seul bloc `modules:` ; syntaxe : `MODULE: true`/`false` (scalaire) ou bloc avec `enabled:` + config ; rétrocompat `lua_modules`/`community_scripts` avec warning pendant 1 version | `lua_config_generator.py`, `mission_builder_worker.py`, `v5_converter.py`, `config_migrator.py`, tests, docs | feat | 3h | ✅ |
| YAML-UX-004 | Listes toujours en style bloc (`-`) dans fichiers générés et template | Supprimer `groups: ["A", "B"]` et `enemy_coalitions: [BLUE]` → style bloc dans tous les fichiers générés par `v5_converter.py` et `lua_config_generator.py` | `lua_config_generator.py`, `v5_converter.py`, template `mission.yaml` | feat | 30 min | ✅ |
| YAML-UX-005 | En-tête syntaxe YAML dans `mission.yaml` généré + template + doc | Ajouter un bloc commentaire en tête expliquant : indentation espaces, règle des guillemets, style liste bloc, booléens — aussi dans `doc/` | `lua_config_generator.py`, `v5_converter.py`, template `mission.yaml`, `doc/GUIDE*.md` | doc | 30 min | ✅ |
| YAML-UX-006 | `migrate-config` : migrer fichiers existants vers nouvelle syntaxe | Ajouter une migration dans `config_migrator.py` pour convertir `lua_modules`/`community_scripts` → `modules:`, `enable` → `enabled`, `{}` → null, listes inline → bloc | `config_migrator.py`, tests | feat | 1h | ✅ |
