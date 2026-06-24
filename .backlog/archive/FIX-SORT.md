# Lot FIX-SORT — LUADATA FIX: Crash tri clés mixtes int/str ✅

Status: ✅ done

**Goal**: Corriger le `TypeError: '<' not supported between instances of 'int' and 'str'` dans `luadata/serializer/serialize.py`.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| SORT-001 | Convertir la clé en `str` dans `sort_key` de `_sort()` | fix | 5 min | ✅ |
| SORT-002 | Test unitaire : `_sort` avec clés mixtes ne plante pas | test | 10 min | ✅ |
