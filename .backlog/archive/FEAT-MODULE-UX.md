# Lot FEAT-MODULE-UX — Catégories, modules obligatoires, dépendances ✅

Status: ✅ done

**Goal**: Améliorer la section `lua_modules:` : catégories cosmétiques, warning modules obligatoires, résolution automatique des dépendances.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| MODUX-001 | `_MODULE_CATEGORIES` dict + headers dans YAML template et Lua output | feat | 20 min | ✅ |
| MODUX-002 | `_MANDATORY_MODULES` frozenset + warning si `enable: false` | feat | 10 min | ✅ |
| MODUX-003 | `_MODULE_DEPS` dict + `_resolve_deps()` — auto-enable en mémoire | feat | 30 min | ✅ |
| MODUX-004 | Update `src/defaults/mission-folder/mission.yaml` — ordre catégories + annotations | doc | 15 min | ✅ |
| MODUX-005 | Tests unitaires (catégories, mandatory warning, deps, transitive chain) | chore | 30 min | ✅ |

**Raw total: 105 min → ~120 min (~2h)**
