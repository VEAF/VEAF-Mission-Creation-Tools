# 04 — WW2 tables of `veafCasMission` reuse modern infantry and a Bradley

Status: ✅ done
Type: fix (data)
Files: `src/scripts/veaf/veafCasMission.lua` (`INFANTRY_TYPES`, `INFANTRY_IFV_TYPES`), the test that sweeps the tables

## What happens

For `veaf.ERA.WW2` the tables are almost right (armour: Sd.Kfz 251/234, Pz IV, Tiger, Panther; Sherman, Cromwell, Churchill; trucks: Opel Blitz, Willys, CCKW), except:

- `INFANTRY_TYPES[BLUE|RED][WW2]` is the **modern** list: blue `Soldier RPG`, `Soldier M249`, `Soldier M4 GRG`, red `Paratrooper RPG-16`, `Infantry AK ver3`, `Infantry AK ver2`. The database has `soldier_wwii_us`, `soldier_wwii_br_01` and `soldier_mauser98`.
- `INFANTRY_IFV_TYPES[BLUE][WW2]` tiers 3 to 5 are `M-2 Bradley`. `M2A1_halftrack` is the tier 1-2 entry; tier 3+ should be heavier WW2 vehicles (`M8_Greyhound`, `Daimler_AC`), not a Bradley.

So `-infantry`, `-combat` and the `_spawn infantrygroup` family put an M4-armed modern rifleman, or a Bradley, in front of a Tiger.

## Done when

The era sweep (the test that checks every entry against the database) also checks that no `WW2` entry is a type dated after 1945 — give the database an era per unit, or keep a short WW2 allow-list in the test. The tables above are corrected.

## Done

`INFANTRY_TYPES[BLUE|RED][WW2]` are now `soldier_wwii_us` / `soldier_wwii_br_01` and `soldier_mauser98`; `INFANTRY_IFV_TYPES[BLUE][WW2]` tiers 3 to 5 are `M8_Greyhound` and `Daimler_AC`. One correction: tiers 1-2 hold `APC M2A1 Halftrack`, the display name of `M2A1_halftrack` (the lookup takes either). The era sweep gained `test_every_ww2_entry_is_a_type_of_the_era`, with a short allow-list of WW2 types; it was checked to fail against the old tables.

## Also measured: WW2 anti-aircraft guns cannot move

On 2026-10-13, in DCS, `Unit:getDesc().speedMax` of every WW2 anti-aircraft type of the database is **0**: `flak18`, `flak30`, `flak36`, `flak37`, `flak38`, `flak41`, `bofors40`, `QF_37_AA`, `M1_37mm`, `M45_Quadmount` (against `Pz_IV_H` 10.6, `Sd_Kfz_251` 14.7, `Sd_Kfz_7` 13.9, `Sd_Kfz_234_2_Puma` 25, `M2A1_halftrack` 20 m/s). A convoy group holding one ran at 4-5 m/s instead of the 11 m/s written on its route (three convoys, 586 m in 120 s). `generateAirDefenseGroup-*-WW2-*` and any convoy whose `defense` adds air defence therefore build WW2 convoys that crawl; the era tables should give WW2 convoys no AA (or armed light vehicles), and the guide should say so.

Not done in this lot: the DCA of the WW2 convoys (the era tables still give a convoy `defense` pieces that cannot move). It goes with ticket 15, which measures the convoy speed.
