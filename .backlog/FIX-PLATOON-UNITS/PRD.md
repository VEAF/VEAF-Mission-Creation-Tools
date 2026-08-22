# FIX-PLATOON-UNITS — the platoon spawner does not know the units the database does

Status: ✅ done — shipped in 6.15.25

Origin: [#296](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/296). Its sibling #295 (the
unit *list*) is closed and done; this is the same request on the other surface.

## The gap

The Currenthill units are in `veaf_libs/data/dcsUnits.yaml` and `dcsUnits.lua`, kept fresh by
`update-dcs-data`. A platoon composition, though, is a **hand-written table** in `veafCasMission.lua`
(armour tiers at `:264-273`), and `Oplot`, `T-90M` and `Terminator` appear in none of them. So the
data pipeline gains units and the spawner never sees them — not a missing entry, but a table that
does not read the database.

## Scope

Add the modern units, and decide whether the tiers should be **derived** from `dcsUnits` by era and
role instead of hand-written. Deriving stops this recurring; hand-editing ships this week. Record
which was chosen, and why.

## The derive-vs-hand-write decision: hand-write, and the data decided it

**Deriving is not possible**, and that is a fact about the data rather than a preference. A generated
record holds `type`, `name`, `kind`, `category` and the DCS `attributes` — and **neither an era nor a
tier**. A tier is an editorial judgement of relative power (a BMP-1 is tier 1, a T-90 tier 5) and an era
is a judgement of period; nothing in `dcsUnits` expresses either. Deriving would mean inventing the data
first, in a second hand-written table, which is the same problem one level down.

So the tables stay hand-written, and what stops #296 recurring is **the sweep**, not derivation: every
entry of every type table is checked against the database, so a type DCS renames or drops fails the build
instead of silently spawning nothing. Adding units fixes today; the sweep fixes tomorrow.

## What the sweep found on its first run, before anything was added

`"APC TPz Fuchs"` appeared in **six** places — `ARMOR_TYPES[BLUE][COLD_WAR]` tiers 1–3 and
`INFANTRY_IFV_TYPES[BLUE][COLD_WAR]` tiers 1–3 — and resolved to **nothing**.

Not a typo in this repository. The name DCS ships is `'APC TPz Fuchs '`, **with a trailing space**, and
`findDcsUnit` compared it untrimmed. Two of the 873 units in the database have one (`TPZ` and `MCV-80`);
no `type` does. So a blue cold-war platoon has been drawing from a list where one entry in three or four
produced no vehicle, quietly, and the only trace was a log line.

Fixed at the source: `veafUnits.findDcsUnit` now compares trimmed values, which also fixes it for a
mission maker who reads a name off the mission editor and types it — the space being invisible. The
tables were switched to the **type id** (`TPZ`) as well, since a type id is stable and a display name is
what carried the space.

A test in `test_veafCasMission` asserts the database *still* has padded names, so the trim becomes
recognisably dead code if a regeneration ever cleans them up, rather than being carried forever.

## The units added

All nine Currenthill armour units the pipeline had gained, placed by role and period:

| Type | What it is | Placed |
|---|---|---|
| `CHAP_T84OplotM` | MBT T-84 Oplot-M | BLUE modern, tier 5 |
| `CHAP_M1130` | IFV M1130 Stryker CV | BLUE modern, tiers 3–4 |
| `CHAP_MATV` | APC MRAP M-ATV | BLUE modern, tiers 1–2 |
| `CHAP_FV101` | LT FV101 Scorpion | BLUE cold war, tiers 3–4 |
| `CHAP_FV107` | Scout FV107 Scimitar | BLUE cold war, tiers 1–2 |
| `CHAP_T90M` | MBT T-90M | RED modern, tier 5 |
| `CHAP_BMPT` | IFV BMPT Terminator | RED modern, tiers 4–5 |
| `CHAP_T64BV` | MBT T-64BV Type 2017 | RED modern, tier 4 |
| `T-90` | MBT T-90A | already present, RED modern tier 5 |

The three the PRD named — Oplot, T-90M, Terminator — have a test of their own, so "can appear in a
spawned platoon" is asserted rather than assumed.

## Definition of done

- [x] The units listed on #296 can appear in a spawned platoon — named explicitly in a test
- [x] A test asserting a composition draws only from types the database knows — **enumerated**, every
      entry of all four type tables, plus a check that no tier above 0 is empty
- [x] The derive-vs-hand-write decision recorded here — hand-write, because the database carries neither
      era nor tier; the sweep is what stops the recurrence
