# FIX-ALIAS-SKIPS-HANDLER-LEVEL — An alias runs its command below the level the command declares

Status: ✅ done

Found by FEAT-OPEN-TRAINING-KNEEBOARD (#1258) while writing the commands sheet, surveyed by the control session on 2026-11-10; David: "oui fais ça".

## The defect

`veafCommands.registerCommandHandler` makes each module declare its level, and the dispatcher enforces it before the handler runs (`veafCommands.SECURITY_CHECKS`).
But `VeafAlias:execute` (`veafShortcuts.lua`, around line 375) does not go through the dispatcher: it calls each module's `executeCommand` directly, in a chain.
For a module whose level is enforced **by the dispatcher**, the alias path therefore skips that level.
The only check left on that path is the alias's own, `isKnownPilot` (or the alias password), so the command runs at **VEAF pilot** level, whatever its module declares.
It is not open to everyone: a pilot who is not on the list is still refused, unless the alias bypasses security.

Modules that check by themselves are not affected:
- `veafSpawn` applies its `SECURITY_CHECKS` centrally, per command;
- `veafCasMission` is `SECURITY_HANDLED`.

## Survey (2026-11-10)

Each module in the alias chain, with the level its dispatcher registration declares:

| Module | Declared level | Aliases reaching it | Effective level through the alias | Gap |
|---|---|---|---|---|
| `veafMove` (`_move`) | trusted member | `-tankerlow`, `-tankerhigh`, `-tankerhere`, `-afachere` | VEAF pilot | **yes** |
| `veafRadio` (`_radio`) | trusted member | `-send`, `-play` | VEAF pilot | **yes** |
| `veafGroundAI` (`_gc`) | VEAF pilot | `-ai_set` | VEAF pilot | no |
| `veafNamedPoints`, `veafSecurity` | open | `-point`, … | VEAF pilot or open | no (stricter) |
| `veafSpawn`, `veafCasMission` | checked by the module | most aliases | as declared | no |

Six aliases are affected.
Re-read the chain and the registrations when implementing: this table is a survey, not a test.

## Questions (reco for each)

| # | Question | Reco |
|---|---|---|
| Q1 | The mechanism | When an alias does not bypass security, `VeafAlias:execute` also applies the declared level of the handler its command reaches: look the handler up by keyphrase in `veafCommands`, and run that handler's `SECURITY_CHECKS` entry. One rule for every alias, and a new module cannot reopen the gap |
| Q2 | The intended level of the four `veafMove` aliases | **Decided by David (2026-11-10): VEAF pilot** for `-tankerlow` / `-tankerhigh`, which stay on the Open Training commands sheet; `-tankerhere` and `-afachere` follow them (same module, same use). The alias declares that level explicitly, so the level is written down rather than leaked |
| Q3 | The intended level of `-send` / `-play` | Trusted member, as declared: a message or a sound reaches everyone on the server |
| Q4 | The Open Training commands sheet | The tanker aliases go from `[confiance]` (#1258) to `[pilote VEAF]` |

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [Aliases enforce the reached handler's level](tickets/01-enforce-handler-level.md) | ✅ |
| 02 | [Levels of the six aliases, commands sheet, doc](tickets/02-levels-and-sheet.md) | ✅ |

Lua runtime, luaunit tests with the DCS mocks. One branch, one PR.

## Outcome (2026-11-10)

Measured with the red tests: the survey's "VEAF pilot" column was wrong. A plain `VeafAlias` runs no check of its own — `isKnownPilot` guards only batch aliases and the combat-mission alias classes — so through an alias `_move`, `_radio` and `_gc` ran for **any** player, unknown to the server included.
`-ai_set` and the twelve `-arty1_*` … `-arty3_*` aliases were open as well; the Q1 rule puts them at `_gc`'s VEAF-pilot level.

Done in one PR: `veafShortcuts.securityLevelFor` (declared level, else the level of the handler matched by keyphrase at the start of the alias's own command), enforced in `VeafAlias:execute` through `veafCommands.isAllowed`; `VeafAlias:setSecurityLevel` on the four `veafMove` aliases; the OT commands sheet; `veafShortcuts` (section *An alias's level*), `ALIASES` and the pilot guide; Lua coverage floor 83 → 84.
