# FEAT-AIRBASE-DUMPS-ALL-THEATRES — the last 7 theatres, captured by Reaper

Status: ✅ done

## Context

`FEAT-AIRDROMES-RUNTIME-SOURCE` rebuilt `airdromes.yaml` from runtime captures and shipped
the **map-capture kit** so anyone could cover the maps we did not own. Seven maps were left
uncovered, listed as a to-do in the helper procedure.

**Reaper captured all seven** with the kit — Nevada, The Channel, South Atlantic
(`Falklands`), Kola, Afghanistan, Iraq, Marianas WWII — which is exactly the outcome the kit
was built for: the data collection is now genuinely delegable.

## Result

`airdromes.yaml` goes from **7 theatres / 657 airbases** to **14 theatres / 810 airbases**.
Every current DCS map now resolves a QRA `airport_link` and a `warehouses.yaml` airfield.

| Theatre | Airbases | | Theatre | Airbases |
|---|---|---|---|---|
| Afghanistan | 29 | | MarianaIslandsWWII | 11 |
| Caucasus | 21 | | Nevada | 17 |
| Falklands | 27 | | Normandy | 90 |
| GermanyCW | 227 | | PersianGulf | 30 |
| Iraq | 20 | | SinaiMap | 56 |
| Kola | 37 | | Syria | 225 |
| MarianaIslands | 8 | | TheChannel | 12 |

## Validation before committing

Each file was checked rather than trusted: valid JSON, expected schema (`id`/`name`/`lat`/
`lon`/`coalition` on every record), integer ids, no duplicate name within a theatre, and the
`theatre` field matching the filename. All seven passed.

**One anomaly found, kept deliberately**: DCS exposes **no coordinates** for three Afghanistan
forward bases — `FOB Thunder`, `FOB Camp Dubs`, `FOB Clark` all report lat/lon ≈ 0. Their
name and id are valid, and the name→id table is all `airdromes.yaml` consumes, so dropping
them would only lose three usable `airport_link` targets. Worth knowing if the geo data in
the JSON dumps is ever used for placement.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Validate + commit the 7 dumps, regenerate the table, update the docs | ✅ |

## Doc consequence

The helper procedure's "still to collect" checklist is now empty, so it was rewritten: every
map ticked (crediting David and Reaper), and the remaining triggers spelled out — a brand-new
DCS map, or an existing map gaining airfields in an update.

---

## 01 — Integrate Reaper's 7 captures

Status: ✅ done
Type: feat

### Tasks

- [x] Sanity-check the 7 JSON files (schema, int ids, no duplicate names, theatre field vs
      filename) — all passed; three Afghanistan FOBs have null coordinates (kept, see PRD).
- [x] Commit them under `veaf_build/dcs_data/airbase_dumps/`.
- [x] `veaf-build update-dcs-data --airdromes` → **14 theatres, 810 airbases**.
- [x] Spot-check a known airfield per new theatre (Nellis=4, Manston=5, Bodo=7,
      Baghdad International=2, Port Stanley=1, Kabul=17, Rota=9).
- [x] Helper procedure (FR/EN): all maps ticked, contributors credited, and the two cases
      that would still call for a capture spelled out.
- [x] Developer doc: coverage stated (14 theatres / 810).
- [x] CHANGELOG + version bump.
