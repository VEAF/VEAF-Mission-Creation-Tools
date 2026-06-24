# Lot FEAT-PROFILES — profils de build dans mission.yaml ✅

Status: ✅ done

**Goal**: Permettre des profils nommés dans `mission.yaml` (`TEST`, `SERVER`) applicables via `veaf-tools build --profile TEST`.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| PROF-001 | `resolve_profile()` + deep merge dans `veaf_libs/build_profiles.py` | feat | 45 min | ✅ |
| PROF-002 | Option `--profile` / `-p` sur `veaf-tools build` | feat | 30 min | ✅ |
| PROF-003 | Log du profil actif au build | feat | 10 min | ✅ |
| PROF-004 | Exemple `profiles:` commenté dans `src/defaults/mission-folder/mission.yaml` | doc | 15 min | ✅ |
| PROF-005 | Tests unitaires | chore | 30 min | ✅ |
| PROF-006 | Doc "Build Profiles" dans `MISSION_YAML_REFERENCE.md` + `GUIDE.md` | doc | 30 min | ✅ |

**Raw total: 160 min → ~185 min (~3h)**
