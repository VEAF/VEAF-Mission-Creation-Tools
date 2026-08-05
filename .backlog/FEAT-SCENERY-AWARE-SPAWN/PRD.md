# FEAT-SCENERY-AWARE-SPAWN — scenery-aware ground spawning from TUM's native tier

Status: 🧑 waiting-human

> **Code delivered 2026-08-05** (tickets 02–05). The lot stays open on ticket 01 alone: the in-game
> probe of `Disposition`, which needs a human at a DCS install. Until it runs, the scenery avoidance is
> asserted rather than measured — see [ADR 0018](../../docs/adr/0018-undocumented-dcs-api-dependency.md).

Origin: [`docs/exploration/TUM-EXPLOIT.md`](../../docs/exploration/TUM-EXPLOIT.md) 🟢 native tier,
[ROADMAP](../../ROADMAP.md) §4 `TUM-EXPLOIT`. Unblocked by §3 (v6.10.0 cut to `master`, 2026-07-18).

## Problem

VEAF places ground units with **no notion of scenery**. The single placement test is
`veafUnits.checkPositionForUnit` (`veafUnits.lua:382`), and it asks one question:

```lua
local landType = land.getSurfaceType(vec2)
...
if landType == land.SurfaceType.WATER then return false end   -- :411
```

Water or land. Nothing else. So a spawn on a marker dropped over a village or a pine forest
puts a platoon inside buildings and trees — clipped into geometry, immobilised, or trading fire
through walls. Four callers share that validator (`veafCasMission.lua:1035`,
`veafSpawnAircraft.lua:122`, `veafSpawnCore.lua:683`, `veafSpawnGround.lua:242`) and **none of
them looks for a better point**: `veaf.placePointOnLand` (`veaf.lua:1115`) only lowers a vec3
onto the terrain height, it never moves it laterally.

This is not a reported bug — it is a quality floor nobody has had a tool for. Every mission that
spawns ground units is affected, including the ones built by `convert-v5`.

## The borrowed technique

TUM calls an **undocumented native DCS singleton**, `Disposition`:

```lua
-- TheUniversalMission.lua:3060, inside DCSEx.world.findSpawnPoint
local spawnPoints = Disposition.getSimpleZones(basePoint, math.max(1852, safeRadius * 5), safeRadius, 1)
if #spawnPoints > 0 and land.getSurfaceType(spawnPoints[1]) == land.SurfaceType.LAND then
    return spawnPoints[1]
end
```

`getSimpleZones(centerVec3, searchRadius, exclusionRadius, count)` returns ground points **clear
of buildings and forests** — per TUM's author, plausibly what ED's own quick-action generator
uses. It needs no unsanitize, no `net.dostring_in`, no external file: it is reachable from the
standard mission scripting environment.

**What is evidence and what is not.** The evidence is one call site invoked bare — no `require`,
no `if Disposition then` guard — plus the author's r/hoggit claim that it is an undocumented DCS
API. That is strong, but **we have not measured it ourselves**, and it is absent from
[`dcs-world-schema`](https://github.com/YoloWingPixie/dcs-world-schema), so neither its presence
across DCS versions and theatres nor the exact argument semantics are confirmed.

**The probe is deferred** (David, 2026-08-05): ticket 01 no longer gates the code. That is safe
because the assumption is load-bearing in one direction only — if the singleton turns out absent or
useless, the search falls through to its second tier and ground spawns behave as they do today. What
stays unverified until ticket 01 runs is the per-call cost and the avoidance itself, so ADR 0018 must
record the scenery avoidance as **asserted, not measured**.

**Licensing.** The bundled `TheUniversalMission.lua` carries **no licence header at all**. A DCS
API signature is a fact, not expression, so calling `Disposition.getSimpleZones` is unencumbered
— but no TUM code is copied, and `findSpawnPoint` is re-derived, not transcribed. Same discipline
as the GPL fence in `DCS-SMS-EXPLOIT.md`.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Probe `Disposition` in a running DCS — existence, signature, behaviour, cost, cross-theatre. **Deferred**, no longer a gate | 🧑 |
| 02 | `veaf.findSpawnPoint` — three-tier search + i18n key + `.luacheckrc` global | ✅ |
| 03 | Wire it into the five jittering spawn paths; failure aborts with a message | ✅ |
| 04 | Typed trigger-zone property accessors (independent of 01–03) | ✅ |
| 05 | Docs + ADR 0018 recording the dependency on an undocumented API | ✅ |

## The search, as David specified it (2026-08-05)

Not "try the singleton, else today's behaviour". Three bounded tiers:

1. Look for a point meeting **all** criteria, scenery included, a bounded number of times.
2. Failing that, a point meeting **every criterion except scenery** — bounded again.
3. Failing that, **fail with a message**.

This is better than a plain fallback, and it changes the honest claim the DoD can make. Today the five
affected callers jitter **once** with `mist.getRandPointInCircle` and use the result **unvalidated**:
a marker near a coast puts the group centre in the sea, and the units are then dropped one at a time
downstream by `validateSpawnPosition` — a spawn producing nothing and N messages. Tier 2 validates and
retries, so that spawn now works. So the behaviour is **not** identical to today when `Disposition` is
absent, and claiming otherwise would be false; the guarantee is narrower and worth more: no spawn that
works today can start failing.

## Why this is not a change to `checkPositionForUnit`

The obvious-looking move — teach `checkPositionForUnit` about scenery — is wrong, and the reason
matters for reviewers. That function is a **boolean validator**: given a point and a unit, is this
legal? `Disposition.getSimpleZones` is a **point finder**: given a centre, where *should* this go?
Folding the finder into the validator would either make it reject positions it has no alternative
for (spawns silently failing where they used to work) or make a validator mutate its input.

So the finder is a new helper, called where a spawn point is **chosen**, and the validator keeps
its current contract. `checkPositionForUnit` is left untouched — RULE N°1.

## The rider — typed zone properties

`veaf._discoverTriggerZones` already carries `properties` through verbatim (`veaf.lua:4375`) and
**nothing in the codebase reads it**. TUM exposes typed readers over the same raw DCS structure
(`DCSEx.zones.getPropertyBoolean/Float/Int/Parse`, `:3257-3271`). That is ticket 04.

It has **no dependency on 01–03**. It was originally included so the lot could not land empty if the
probe came back negative — an argument that lapsed when the probe was deferred and the code went ahead.
It stays because it is written, independent and cheap, and it is done **last**, after the spawn work
that carries the actual value. It is grouped here only because the roadmap groups it (same 🟢 tier,
same source); it lifts out into its own `CHORE-` cleanly if preferred.

## Out of scope

- **TUM's 🔴 server tier** — `net.dostring_in` + the `a_*` internals (live HP, live briefing, JSON
  persistence). Needs an `autoexec.cfg` unsanitize on the *player's* install, so it is
  incompatible with a publicly distributed mission, and it collides with the SECREV
  "no arbitrary Lua execution" policy. That work belongs to `PERSISTENCE` / `DYNAMIC-CAMPAIGN`.
- **A `veafTum.lua` wrapper.** TUM stays the opt-in black box it is today (`TUM: true` →
  `TUM.initialize()`). We borrow a DCS call, we do not start a dialogue with TUM.
- **Patching TUM in place.** Depending on the upstream 30k-line file creates merge debt on every
  bump; the pattern is extracted into VEAF modules instead.
- **Air and naval spawning.** `getSimpleZones` is about ground clearance.

## Risk

The lot rests on an undocumented API, and now also on an unrun probe. Mitigation is structural, not
hopeful: tier 1 is guarded (`if Disposition and Disposition.getSimpleZones then`) and `pcall`-wrapped,
so a missing singleton, a signature change between DCS patches, or an outright error falls through to
tier 2 instead of killing a spawn. The mock covers the **absent** branch permanently, because that is
what ships to any install lacking it.

The residual risk the deferred probe leaves is not correctness but **value**: tier 1 could turn out to
avoid nothing, in which case we have paid for a tier that never helps. Ticket 01 settles it, and its
negative outcome is a deletion, not a debugging session.

## Definition of Done

- Ground spawns avoid buildings and forests when `Disposition` is present and productive.
- **No spawn that works today starts failing** — the honest guarantee, weaker than byte-identical
  (see the search section above) and verified by the existing ground-spawn tests staying green except
  where a change is justified as the tier-2 validation improvement.
- A spawn with no acceptable point anywhere aborts once, with a message, respecting `silent` — instead
  of running to completion and dropping every unit one at a time.
- `test/lua/dcs_mocks.lua` gains a scriptable `Disposition` mock; present, absent, empty and throwing
  are all covered by `poetry run test-lua`.
- Lua coverage floor raised in step with actual measured coverage (ratchet policy — the number only
  goes up).
- `luacheck --config .luacheckrc src/scripts/veaf/` and `stylua --check src/scripts/veaf/` green
  (`Disposition` declared in `.luacheckrc`, with a comment saying it is unverified).
- `doc/LUA_API_REFERENCE.{md,en.md}` document the new helpers; `TUM-EXPLOIT.md` and `ROADMAP.md`
  annotated; ADR 0018 filed, recording the avoidance as asserted rather than measured.
- CHANGELOG entry under `[Unreleased]`; PATCH version bump in `pyproject.toml`.
