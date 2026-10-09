# 09 — "Escort me" in an A-10C answered nothing

Status: 🧑 waiting-human
Type: fix

## Found

David, 2026-10-09, about the flight of 2026-10-08: "j'ai aussi voulu faire un "escort me" en A-10 et j'ai pas eu de réponse ni de spawn d'avion allié".

`veafSpawn.escortMe` (`veafSpawnAircraft.lua`) has four ways to return without a word: the unit not found, no group, no spawnable template matching the search (`fox3`/`fox2`) for the side, or the spawn failing.
Its only trace is a `debug` line, below the mission's `info` level, so `dcs.log` holds nothing of it.

## To do

- Find which return it took: in game, through the fiddle hook, `veafSpawn.findSpawnableAircraftGroupname("fox3", coalition.side.BLUE)` in the mission as built (`R47`).
- Fix that cause, and make every refusal say why to the pilot who asked.
- Lua tests on each refusal.

## Done when

"Escort me" from a blue A-10C dynamic slot of a mission built by `campaign next` spawns an escort, and any refusal tells the pilot why.

## Measured (2026-10-09)

Not reproduced locally: with the mission flown on 2026-10-08 rebuilt as it was, `findSpawnableAircraftGroupname("fox3", BLUE)` finds `veafSpawn-F-15C - FOX3 - Radar ON - ECM OFF - HARD X1`, `spawnEscort` from a script spawns, and "Escort me" works from a placed A-10C in the air and from a dynamic A-10C slot on the ground.
Every refusal now says why, to the pilot and in the log (`info`), so the next one on the server names its cause.

## Left

`R47` item 5, on dcs.veaf.org.
