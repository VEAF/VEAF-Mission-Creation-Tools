# 12 — The `defense` levels and the SAM aliases do not say what they do

Status: ✅ done (#996)
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

## Decisions (David, 2026-09-24)

- Point 2: `-samLR` was never long range — since its first commit (bb8a3545, 2020-03-11) it ran
  `defense 5`, and the defense scale is the CAS escort scale (level 5 = Hawk / Tor). David: keep
  `-samLR` as it is (description corrected to "medium range"), add a `-samVLR` for real long-range
  batteries — agreed with its per-era table and the existing Patriot template (2026-09-24).
- Point 3: era per level, COLD_WAR = types in service around 1980 (the armor tables' reference);
  SA-10 excluded from COLD_WAR.

## Outcome (PR 5)

1. `list_shortcuts` returns `randomParameters` (`{name: {min, max}}`) for each `#command` alias,
   parsed from `:addRandomParameter` by `veaf_shortcuts_scanner`.
2. Air-defense groups: `generateAirDefenseGroup` looks up `generateAirDefenseGroup-<SIDE>-<ERA>-<N>`
   first, then the generic level. 16 variants in `veaf-units.yaml`: COLD_WAR blue 1–3 and red 5,
   WW2 flak for every level of both sides. Swept per (side, era, level) in
   `test_air_defense_eras.py`.
3. Escorts (`_addDefenseForGroups`): `ESCORT_TYPES_REPLACED_BY_ERA[COLD_WAR]` swaps the post-1980
   types; swept over every level, both sides, vehicles and manpads. **Found on the way:** the escorts
   were skipped on `veaf.config.ww2`, which a v6 mission never sets (only v5 `missionConfig.lua`
   did), so WW2 sections got modern escorts; now also skipped on `era: WW2`.
4. The ±1 roll documented (veafCasMission doc, FR/EN), the "30 %" comment fixed in both places it
   appeared, and the false "Difficulty reference" table (level 5 = SA-6/SA-11, never placed)
   replaced by what the escort really places.
5. `-samVLR` → `_spawn longrangesam` → `veafCasMission.generateLongRangeAirDefenseGroup`, drawing
   from `LONG_RANGE_AIR_DEFENSE_GROUPS[side][era]`: MODERN SA-10 / SA-5 (red), Patriot (blue);
   COLD_WAR SA-2 / SA-5 (red), Hawk (blue); WW2 the heaviest flak level. The Patriot template has
   been in `veaf-units.yaml` since 2019 (faa1d19e) — a first grep missed it and a duplicate was
   briefly written, then removed; the 159 Patriot groups measured in the `.miz` under
   `D:\dev\_VEAF` confirm its core (STR, ECS, EPP, CP, AMG, 4+ launchers). The era swap also
   applies to the point defense these templates carry (the Hawk's Avenger).
