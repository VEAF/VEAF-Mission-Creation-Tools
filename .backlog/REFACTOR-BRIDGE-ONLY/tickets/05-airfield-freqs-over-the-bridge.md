# 05 — Airfield frequency capture over the bridge

Status: ⬜ ready

`veaf-build update-dcs-data --airfield-freqs --capture` read `Terrain.GetTerrainConfig` and `DCS.getATCradiosData` in the hook's GUI environment.
The blank capture missions now carry the bridge, and the capture chunk is sent to the `gui` state through `net.dostring_in`, JSON-encoded there with `net.lua2json` since only a string crosses.

Done when: the session is unit-tested against a fake bridge, and one theatre is captured in game.
