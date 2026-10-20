# 04 — sweep the missing theatres and publish the release

Status: ✅ done

David runs DCS: `veaf-tools dcs terrain-sweep` for Caucasus, then GermanyCW, MarianaIslands, MarianaIslandsWWII, TheChannel and Afghanistan if his licences open them (Kola and Iraq are not installed on his PC).

Publishing is an outward action: the asset list and sizes are shown, and the release goes out on David's explicit go.

## Done when

- The `terrain-data` release holds at least the five existing grids, and Caucasus once swept.
- `gh api repos/VEAF/VEAF-Mission-Creation-Tools/releases/latest` still answers the tools' release.
- `describe_terrain` answers on a PC with no local grid.

## Measured (2026-10-20)

| theatre | cells | sweep | file | ground |
|---|---|---|---|---|
| Caucasus | 26.5 M | 4 min 25 | 3.6 MB | 0–5 565 m |
| GermanyCW | 10.2 M | 3 min 46 | 4.0 MB | 0–1 524 m |
| MarianaIslands | 33.3 M | 5 min 33 | 31 kB | 0–1 015 m |
| MarianaIslandsWWII | 20.8 M | 3 min 28 | 26 kB | 0–969 m |
| Afghanistan | 35.4 M | 6 min 45 | 18.8 MB | 0–7 975 m |
| TheChannel | 0.8 M | 16 s | 304 kB | 0–274 m |

Some 1.5 s per batch of 20 000 heights was announced; measured, about 0.2 s. A sweep started while the previous survey mission still ran stops at once ("the running mission is on GermanyCW"): start it once the new mission is loaded.
On an empty `VEAF_HOME`, `describe_terrain` downloaded Syria (4.6 s), Caucasus (7.0 s) and MarianaIslands (4.3 s) and answered.
