# REFACTOR-MARKER-PARSER — one marker text parser instead of ten

Status: ⬜ ready

## Why this exists

`SECREV-2` ticket 06 recommended fixing a family of crashes "in the shared marker parser".
**There is no shared marker parser.** Measured 2026-08-08: ten modules carry their own
`markTextAnalysis`, totalling **641 lines**.

| Module | Lines |
|---|---:|
| `veafCasMission` | 125 |
| `veafMove` | 115 |
| `veafGroundAI` | 97 |
| `veafSpawnParser` | 86 |
| `veafTransportMission` | 76 |
| `veafRadio` | 64 |
| `veafSecurity` | 28 |
| `veafShortcuts` | 20 |
| `veafNamedPoints` | 19 |
| `veafRemote` | 11 |

They parse the same shape of input — a keyphrase, then comma-separated `key value` pairs — and
each one re-implements the reading, the conversion and the defaulting. That duplication is not a
tidiness complaint: it is where the bugs are.

## The evidence, not the theory

Every one of these came from the same duplication, and each was fixed in one place only:

- **VMR-019** — `string.format("%d", nil)` and `tonumber(nil) <= 5` on a valueless keyword, in
  `veafCasMission`, **four times over** in the same function (`size`, `defense`, `armor`,
  `spacing`). A typo cost the whole command rather than one parameter.
- **VMR-025** — a non-numeric `multiplier` aborts a spawn, in `veafSpawnParser`.
- **VMR-004** — the SRS marker path built a shell command from unvalidated marker text.
- The review's own "siblings in the low tail": the same shape again, in modules nobody has
  touched yet.

`veaf.safeNumber` (added by SECREV-2 ticket 06) shares the *conversion*. It does not share the
parsing, the keyword table, or the defaulting — so the next module still gets to reinvent them.

## What this lot is

Extract one parser the ten modules call, and delete what it replaces.

**Not** a rewrite of what each command *does* with its parameters — only how they are read,
converted and defaulted. The behaviour of every existing marker command must be identical
afterwards, which is what makes this reviewable at all.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Characterise the ten parsers before touching them](tickets/01-characterise.md) | ⬜ |
| 02 | [Build the shared parser against those characterisation tests](tickets/02-shared-parser.md) | ⬜ |
| 03 | [Migrate the ten modules, one per commit](tickets/03-migrate.md) | ⬜ |

## Why it is worth doing, and why it is not urgent

Worth doing: 641 lines collapse, and the crash family stops recurring by construction rather
than by remembering. Every marker command in the product goes through this code, so the same
defect keeps arriving through a different door.

Not urgent: `veaf.safeNumber` and the per-site fixes have taken the sharp edges off the known
instances. This is the structural cure, not the emergency treatment — and it touches every
marker command in the product, so it wants a quiet moment and a full `test-lua` run, not a
squeeze between two security tickets.

## Risks

- **Behaviour drift.** Ten parsers have ten sets of quirks, and some are load-bearing (a module
  that accepts a keyword with no value, another that treats `0` as absent). Ticket 01 exists to
  pin those *before* anything moves.
- **It is a wide blast radius by definition.** Every marker command depends on it. `test-lua`
  covers 36 suites and is the gate; a Lua 5.1 interpreter is available on `DAVID-BUREAU`, so a
  local red/green is reachable — see the note in the agent memory.
