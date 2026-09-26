# 10 — Settle the group by rigid translation, not unit by unit

Status: ✅ done — merged 2026-09-26 (PR #1005)
Type: fix

## Problem — ticket 08 never moved anything

`veafUnits.settlePosition`, delivered by ticket 08, has **never displaced a single unit**. Measured
in DCS on GermanyCW-v6, 2026-09-25:

- called on units genuinely stuck under trees, with a free spot 50 m away and 10 candidates offered
  by DCS: **0.0 m of displacement, every time**;
- over 20 stuck units: **25 candidates returned by `Disposition.getSimpleZones`, 25 valid on terrain,
  0 accepted**;
- actual distance of those candidates: **min 52 m, median 130 m, max 171 m**.

The cause is arithmetic. The function loops over the radii `{ 10, 25, 50 }` and keeps a candidate
only when `dist <= r`. **DCS does not honour the radius it is asked for**: asked 50 m, it answers at
130 m. The closest point it has ever returned is 52 m — just above the widest ring. The test can
never pass, and the function falls back to `return spawnPosition` every time.

Consequence: on the whole mission the scenery probe still reports **51 alerts over 183 objects**,
exactly as before the lot existed (53/184). Ticket 08 bought nothing on the metric that motivated it.

## Why a per-unit nudge cannot work at all

Measured over the same mission:

- **Per unit**: a group's natural spacing is 20 to 27 m for a SAM battery, and the closest point DCS
  can propose is 52 m. Any per-unit displacement therefore breaks the formation by a factor of 2 to 5.
  No threshold is both effective and safe. Ticket 08's own comment already suspected this — *"the ring
  radii must stay below the group spacing so we do not accidentally merge two vehicles into the same
  clearing"*.
- **Per group, as a rigid translation**: over 31 offending groups, **30 are fully resolved** and stuck
  units drop from **132 to 2**, with the formation preserved to the metre. The translations needed run
  from 100 to 800 m. The six worst (the S-300s of Wittstock and Borkenberge, three other S-300s and an
  SA-11) go from 8-13 units under trees to zero.

The formation must also be settled **after** it is built, because `veafUnits.placeGroup` draws it at
random on every spawn (`math.random` at veafUnits.lua ~569, ~688, ~728). No amount of editing the
positions declared in a mission can substitute: the next draw puts units back in the trees.

## What this ticket does

Replace `veafUnits.settlePosition(spawnPosition, unit)` with
**`veafUnits.settleGroup(units)`**, which translates the whole group rigidly:

- computes the group's footprint radius — the largest distance from the barycentre to a unit;
- asks `Disposition.getSimpleZones` **once**, for a clearance of `footprint + SETTLE_MARGIN`, so any
  candidate it returns is the centre of a clearing that fits the **entire** group;
- keeps the closest candidate whose translation puts **every** unit on `veaf.DRIVABLE_TERRAIN`;
- applies that translation to every unit, so all inter-unit distances are unchanged by construction;
- leaves the group untouched when nothing acceptable is found, or when the best candidate is farther
  than `SETTLE_MAX_TRANSLATION`.

Exemptions are unchanged in substance: an air, naval or naval-static unit anywhere in the group makes
the **whole** group exempt, because a rigid translation is a property of the group and translating
half of it would break the very invariant this function exists to protect.

### The two constants, and why those values

| Constant | Value | Why |
|---|---|---|
| `veafUnits.SETTLE_MAX_TRANSLATION` | 1000 m | The acceptance bound, **not** the radius asked of DCS — the radius asked means nothing, which is the whole defect above. Measured translations needed run to 800 m, so the bound must clear that; 1000 m keeps the group inside the scale of its own combat zone. |
| `veafUnits.SETTLE_MARGIN` | 50 m | Breathing room asked around the footprint, **and** the radius within which a candidate proves the group already stands in that clearing (geometry: a candidate at `d` from the centre has `footprint + margin` clear around it, so every unit is clear as soon as `d <= margin`). The closest candidate DCS was ever measured to return is 52 m, so a tighter margin could never fire that proof. |

## Definition of done

- [ ] A failing test first: a group whose several units stand on refused scenery ends up entirely
      clear **with every inter-unit distance unchanged**
- [ ] `veafUnits.settleGroup` defined and documented; `settlePosition` removed along with its tests
- [ ] Called in `_createDcsUnits`, `doSpawnGroup` and `veafCasMission.generateCasMission`, before the
      terrain check
- [ ] The exemption rests on the **explicit flag** `honourDeclaredPosition`, never on a zero radius:
      zero is this codebase's default, and measured on GermanyCW-v6 on 2026-09-25, **100 of the 118
      spawn commands of one launch pass `radius 0`** — `sa10`, `sa11`, `sa15_squad`, `ewr`,
      `patriot`, `msta`, i.e. every battery this lot exists for. A gate keyed on the radius makes the
      lot a no-op on the real mission while every unit test stays green. Same distinction ticket 07
      drew for `VeafGroupSpawn:honouringDeclaredPosition`, reused rather than duplicated.
- [ ] Two tests pin that gate: a zone spawn at the default radius **is** moved, and a caller that
      honours its declared position is **not**
- [ ] `poetry run test-lua` green, `stylua --check` and `luacheck` clean
- [ ] `CHANGELOG.md` entry under `[Unreleased]`
