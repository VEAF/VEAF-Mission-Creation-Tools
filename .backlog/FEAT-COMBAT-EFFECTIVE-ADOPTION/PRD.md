# FEAT-COMBAT-EFFECTIVE-ADOPTION — adopt the combat-effectiveness predicate beyond the report

Status: ⬜ ready

Follow-up to [`FEAT-GROUP-COMBAT-INEFFECTIVE`](../FEAT-GROUP-COMBAT-INEFFECTIVE/PRD.md), which shipped
`veaf.isGroupCombatEffective` in 6.15.24 and deliberately adopted it in **one** place — the F10 zone
report, because that changes no mission behaviour. The analysis of the other two callers lives in that
PRD; this lot acts on it.

## Skynet first, because it is safe

`veafSkynet.findSkynetElementToDefend` (`veafSkynetIadsHelper.lua:404`) picks which site a point-defence
group protects. With the predicate it would skip sites that can no longer fight, so a Tor does not spend
a mission guarding a decapitated S-300 while a live one goes undefended.

Invisible to a player until it matters, and it cannot end a mission early. Ship this half on its own.

## `completionCheck` needs a decision, not an implementation

Today it counts units of the hostile coalition and completes the zone at zero. With the predicate it
would count only units of groups still effective, and the consequence is a **design** question:

> A zone announcing "all enemies destroyed" while a player can see four intact launchers is either a
> welcome shortcut or a bug, depending on what the mission maker meant.

It also changes **every existing mission** holding a SAM site — a player who used to have to hunt every
launcher would stop having to.

**Put to David before building.** The likely shape is a per-zone switch defaulting to today's behaviour,
following the convention `FIX-COMBATZONE-RENAME-OPTION` established for exactly this kind of change; but
that is a guess, and the arbitration is his.

## Definition of done

- [ ] Skynet skips ineffective sites when choosing what to defend, with tests
- [ ] The `completionCheck` question put to David, and his answer recorded here before any code
- [ ] Whatever is decided for `completionCheck`, documented in both languages — it is visible to players
