# 13 — An ASSETS entry shown to one coalition

Status: ⬜ ready

Files: `src/scripts/veaf/veafAssets.lua`, `veaf_libs/lua_config_generator.py`, `doc/mission-maker/scripts/veafAssets.md`,
Lua and Python tests.

## What happened

With red playable, the Syria mission lists its red tanker and AWACS in the same F10 Assets menu as the blue
ones: `veafAssets` has no notion of coalition, so both sides see every frequency.

## Done when

- `assets[].coalition: BLUE | RED` (absent: both, as today) puts the entry in that coalition's menu only.
- Lua test on the menu built for each side.
