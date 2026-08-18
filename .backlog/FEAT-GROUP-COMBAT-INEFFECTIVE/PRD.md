# FEAT-GROUP-COMBAT-INEFFECTIVE — decide when a group has stopped being a threat

Status: ⬜ ready

Origin: [#177](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/177), 2023, with a proposed
config table in the issue body.

## The idea

A group is not only alive or dead. An S-300 whose tracking radar is destroyed still has launchers and
crew, and counts as alive everywhere in our code — while in play it is finished. The issue proposes
declaring, per group pattern, which units are the **important** ones and what minimum life they need,
defaulting to what DCS's own unit description says (`"SAM TR"` = important).

## Why it is the most structural of the small lots

Three places currently ask "is this group still a problem?" and each answers it its own way:

- `veafCombatZone:completionCheck()` counts **units of the hostile side**, so a toothless SAM keeps a
  zone open
- Skynet decides whether a site is worth defending
- the F10 reports tell a player what is left

One shared predicate would serve all three. Which is also the risk: changing what "alive" means
changes when zones complete. Ship the predicate first and adopt it caller by caller, not in one pass.

## Scope

- a `veaf.isGroupCombatEffective(group)` style predicate, with the pattern/importance table from the
  issue, defaulting to the DCS attributes
- adopted by **one** caller to prove it, chosen with David — `completionCheck` is the visible one and
  therefore the riskiest
- Lua tests on a partially destroyed S-300

## Definition of done

- [ ] The predicate exists, table-driven, with the DCS-attribute default
- [ ] One caller adopts it, and which one is recorded here
- [ ] The other callers listed with what adopting would change for a player
