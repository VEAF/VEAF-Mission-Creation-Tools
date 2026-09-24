# 12 — The `defense` levels and the SAM aliases do not say what they do

Status: ⬜ ready
Type: fix + doc (one design decision, see point 2)
Files: `src/scripts/veaf/veafShortcuts.lua`, `src/scripts/veaf/veafCasMission.lua`,
`src/python/veaf-tools/veaf_libs/data/veaf-units.yaml`, `veaf_mission_mcp` (`list_shortcuts`),
the shortcuts doc, tests

Reported by the GermanyCW-v6 session on 2026-09-24; checked against the code the same day.

## The need

David wants a training zone graded with `defense N` on its `#command` carriers. Three defects stop a
mission maker (or an agent) from doing that with confidence.

## What happens

1. **`list_shortcuts` hides the aliases' random parameters.** `-sam`, `-samSR`, `-samLR` and `-aaa`
   all show `_spawn samgroup, skynet true, spacing 1, radius 0`, while `veafShortcuts.lua` adds a
   different `addRandomParameter("defense", …)` to each: `-sam` 1–5 (l. 1243), `-samSR` 2–3
   (l. 766), `-samLR` 4–5 (l. 758), `-aaa` 1–2 (l. 1251). An agent choosing an alias from the oracle
   cannot tell them apart. The same holds for `-armor`, `-infantry`, `-transport`, `-combat`,
   `-convoy`.
2. **`-samLR` is described "Random long range SAM battery" and places short range.**
   `_spawn samgroup, defense 4-5` → `veafCasMission.generateAirDefenseGroup` (l. 719) →
   `generateAirDefenseGroup-<SIDE>-4/5` in `veaf-units.yaml`: blue level 4 is Roland, blue level 5
   Hawk (medium range); red is Dog Ear, Tor, Osa, Strela-10, Tunguska, ZSU-57-2, S-60. No long range
   anywhere (SA-10, SA-11, SA-5, Patriot). Same question for `-samSR` (2–3) and `-aaa` (1–2: red
   level 2 is SA-9 + Shilka, so not only AAA).
3. **The levels ignore the era.** `generateAirDefenseGroup` picks `generateAirDefenseGroup-<SIDE>-<N>`
   without reading `veaf.config.era`, while `generateTransportCompany` (l. 783) and the armor and
   infantry generators read `…_TYPES[side][veaf.config.era]`. In a COLD_WAR mission dated 1980, blue
   level 3 places an M6 Linebacker (in service 1997) and an Avenger (1989); red level 5, per the
   report, a Tor (1986) and a Tunguska (1982).

Also worth writing down for a mission maker grading with `defense N`: the level is rolled — 20 % one
level lower, 20 % one higher, 60 % as asked (l. 725–733), clamped to 0–5. The comment on l. 725 says
"30 % chance to get a +1"; the code gives 20 %.

## To decide

Point 2: correct the descriptions to what the aliases place, or give `-samLR` real long-range
batteries. Point 3: air-defense levels per era, like the transports.

## Done when

- `list_shortcuts` returns each alias's random parameters and their ranges; the shortcuts doc shows
  them
- Each SAM alias's description matches what it places, or places what it says
- An air-defense level picks era-appropriate units, tested per era
- The ±1 roll is documented, and the l. 725 comment matches the code
