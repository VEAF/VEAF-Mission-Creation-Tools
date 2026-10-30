# 01 — AIEN counter-battery raises on a missing SA

Status: ✅ done

On 2026-10-29 the server log held 49 times `AIEN.lua:5631: attempt to index field 'sa' (a nil value)` in `counterBattery`, called from the hit event. `og.sa` is filled only by the phase cycle, which skips the groups under attack, so an artillery group hit from the start never had one and the counter-battery never fired. The same unguarded read sat at four other places.

Fix: `groupSA(og)` builds the SA on demand when it is missing (or `false`, which `getSA` answers for a group it cannot assess); the five reads and `AIEN_testActions` go through it. Marked `VEAF:` in the vendored file.

Done when: `test/lua/test_aienGroupSA.lua` covers the helper and sweeps the file for any unguarded `<entry>.sa.<field>` read.
