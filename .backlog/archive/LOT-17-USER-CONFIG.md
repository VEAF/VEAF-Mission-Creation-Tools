# Lot 17 — USER-CONFIG: Configuration globale utilisateur + i18n complète

Status: ✅ done

**Goal**: Ajouter un fichier `~/veafmct.yaml` de configuration globale utilisateur ; compléter l'audit i18n (toutes les chaînes des commandes CLI traduites) ; nouvelle commande `user-config`.
**Branch**: `feature/user-global-config` → PR → `develop`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| UC-001 | Créer `veaf_libs/user_config.py` + tests | `user_config.py`, `test_user_config.py` | feat | 45 min | ✅ |
| UC-002 | Brancher `user_config.get_lang()` dans `i18n._detect_lang()` | `veaf_libs/i18n.py` | feat | 15 min | ✅ |
| UC-003 | Brancher `user_config.get_check_updates()` dans `app.py` | `veaf_tools/app.py` | feat | 10 min | ✅ |
| UC-004 | Audit i18n complet — 55+ clés locales + mise à jour de toutes les commandes | `locales/en.json`, `locales/fr.json`, toutes les commandes | feat | 90 min | ✅ |
| UC-005 | Nouvelle commande `user-config` | `veaf_tools/commands/user_config.py` | feat | 20 min | ✅ |

**Estimated total: ~3h**
