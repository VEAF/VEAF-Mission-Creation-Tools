# 01 — Characterise the parsers before touching them

Status: ✅ done
Type: test

## Why first

Ten parsers have ten sets of quirks and some are load-bearing. Replacing them without pinning what
they do today turns a refactor into a behaviour change nobody can review — the diff would show a
parser deleted and a parser added, and no reader could tell which differences were intended.

## Scope

Group A (the six `markTextAnalysis`) and group B (the four loops under other names). Group C is
out of scope for the whole lot; see the PRD.

## Tasks

- [x] For each parser in groups A and B, tests covering: a well-formed command, a keyword with no
      value, a keyword with a non-numeric value, an unknown keyword, an empty command, and the
      keyphrase absent.
- [x] Extend the quirk inventory below with what the tests reveal, rather than normalising
      anything on the spot.
- [x] Note anything that looks like a defect. Do **not** fix it here — a characterisation test
      records what *is*, and a fix in the same commit is invisible.

## Quirk inventory (started 2026-08-11, from reading; to be confirmed by the tests)

Each of these has to be expressible in ticket 02's specification, or the migration silently drops
it.

1. **A valueless keyword arrives as `nil` or as `""`, depending on the module.** `veaf.breakString`
   returns nil; `veafGroundAI`, `veafSpawnParser` and all four group-B loops write `str[2] or ""`,
   while `veafCasMission`, `veafMove`, `veafRadio` and `veafTransportMission` do not. This decides
   whether a bare keyword reads as a flag or as an error, and it is the direct cause of the six
   crashes `FIX-MARKER-PARAM-CRASHES` fixed.
2. **`veafRadio` chains with `elseif`; the other five use separate `if`s.** So in `veafRadio` a key
   fires at most one rule, whereas elsewhere every matching rule runs. `veafSpawnParser` relies on
   the permissive form — its `name` has two rules, the second gated by a `when` predicate.
3. **Only `veafSpawnParser` reports an unknown keyword**, with a nearest-match suggestion. The
   others ignore it in silence. Ticket 02 generalises the reporting version.
4. **Nothing stops at the first bad parameter.** Every parser runs the whole loop.
5. **Out-of-range handling differs**: `veafCasMission` and `veafTransportMission` ignore
   (`veaf.safeNumberInRange`), `veaf.safeNumber` with bounds clamps, and several keywords accept
   anything.
6. **Sentinel defaults are not uniform.** `veafMove` uses `-1` for "keep the original speed or
   altitude"; `veafTransportMission` uses `0` for an absent `defense` or `blocade`.
7. **Case handling is per-keyword, not per-parser.** `side` and `country` upper-case their value,
   `skynet` and `color` lower-case it, and a password is case-sensitive. Keys are always
   lower-cased.
8. **Defaults are seeded by sub-command.** `veafMove` sets speed and altitude from
   `group`/`tanker`/`tankermission`/`afac`; `veafSpawnParser` does it through
   `CommandDescriptors[].init`. First match wins in both.
9. **Mandatory fields are checked after the loop and return nil**, refusing the command:
   `groupName` in `veafMove`, `name` in `veafGroundAI`, `name` per-command in `veafSpawnParser`.
10. **`veafGroundAI` has a spatial fallback inside the parser.** With no `groupname`, `set` and
    `unset` search for the nearest allied unit within 250 m and take its group. A parser that
    reads the game world is worth isolating from one that reads text.

## Confirmed by the tests, and added to the inventory

Measured while writing the suites, none of it visible from reading alone:

11. **A value keeps everything after the FIRST space, and only the first.** So `side  BLUE`
    (two spaces) is the value `" BLUE"`, which is not `"BLUE"` — and `veafCasMission` silently
    resolves that to RED. Any shared parser that trims values would *change* behaviour here.
12. **A repeated keyword ends on the last occurrence** in every group A and B parser, since the
    loop applies rules as it walks and nothing breaks out.
13. **`veaf.trim` runs before the split**, so a trailing space is not a value: `password ` gives
    nil, not `""`. And a comma needs no following space — `_cas,size 3` parses.
14. **Numeric parameters accept decimals.** `size 2.5` is stored as 2.5; nothing requires an
    integer, in any module.
15. **Flags discard any value given to them** rather than interpreting it: `teleport false`
    teleports, `quiet false` is quiet, `silent 0` is silent.
16. **`ArtilleryUnitHandler`'s `target` validates before storing** — `veaf.computeLLFromString`
    must succeed or the parameter is dropped. It is the only parameter rule in the codebase that
    refuses its own input, and the spec has to be able to express that.
17. **Sub-verb chains are decided by the chain's order, not the text's.** `_move group tanker`
    is a group move; `fire aim` is an aim. Reordering the spec's command list changes behaviour.
18. **Group B's three `veafShortcuts` loops are not standalone functions** — the loop is a step
    inside `execute`, which then runs the mission or zone. They are characterised through spies
    on `veafCombatMission` / `veafCombatZone`, by what the parsing hands downstream, which is
    its only observable. Two of the three are the same loop twice, differing only in one
    local's name.
19. **`VeafAlias:setPassword` stores the hash, not the clear text.** Noted because a test that
    passes clear text there never matches and looks like a parser bug.

## Looks like a defect — record, do not pin as intended

- **`veafCasMission`'s `disperse` never becomes the flag it was written to be.**
  `if val ~= "" then tonumber(val) else 15 end` was meant to make a bare `disperse` mean 15
  seconds, but a valueless keyword arrives as `nil`, never `""`, so the `else` is dead and
  `_cas, disperse` leaves the option `false`. Proven with a probe on 2026-08-11.
- **`veafRadio` handles `path` twice in one `elseif` chain** (lines 233 and 253); the second is
  unreachable.
- **`veafGroundAI` calls `Group.getByName("")`** on a valueless `groupname`.
- **`veafMove` overwrites its `-1` sentinel with nil** when `speed`/`hdg`/`alt`/`dist` will not
  convert, so a nil travels downstream instead of "keep the original".
- **`veafShortcuts.lua:288` and `:394` are the same loop twice**, differing only in a local's name.
- **`veafGroundAI` accepts an empty handler name.** `str[2] or ""` makes a valueless `name` the
  empty string, and the mandatory-field guard is `if not options.name`, which does not catch it
  because `""` is truthy in Lua — so `_ground status, name` proceeds with a nameless handler.
  This is **exactly the bug SECREV-010 fixed in `veafMove`**, whose guard reads
  `not switch.groupName or switch.groupName == ""`. The `veafShortcuts` loops guard correctly too
  (`#zoneName == 0`), so `veafGroundAI` is the one that was missed. Recorded, not fixed: it is a
  wrong-input-accepted bug, not a crash, and a declared mandatory parameter expresses it once
  instead of three times.
- **`veafRadio` destroys a default when a recognised keyword has no value.** `_radio transmit,
  freq` sets `frequencies` to nil, and `executeCommand` requires that field — so the command does
  **nothing at all, with no message to the pilot**. An *unknown* keyword is harmless by
  comparison, since it leaves the default intact.

## Acceptance criteria

- [x] Every group A and group B parser has tests that pass **before** any refactoring starts.
- [x] The inventory above is complete, with deliberate quirks separated from accidental ones.

## Coverage delivered

| Parser | Suite | Notes |
|---|---|---|
| `veafRadio` | `TestVeafRadioCharacterisation` | first to migrate; its `elseif` proven unobservable |
| `veafTransportMission` | `TestVeafTransportCharacterisation` | |
| `veafCasMission` | `TestVeafCasCharacterisation` | |
| `veafMove` | `TestVeafMoveCharacterisation` | sub-command default seeding pinned |
| `veafGroundAI` | `TestVeafGroundAICharacterisation` | |
| `veafSpawnParser` | existing suite + `FIX-MARKER-PARAM-CRASHES-2`'s enumerated sweep | already declarative |
| `ArtilleryUnitHandler` (B) | `TestArtilleryOrderTextCharacterisation` | the `;` separator |
| `veafShortcuts` ×3 (B) | `TestShortcutsInlineParserCharacterisation` | via spies; not standalone functions |

**One quirk found only because `veafRadio`'s `elseif` was tested rather than argued**: it is not
observable today, because no key is claimed by two live branches. Ticket 03 may therefore migrate
that module to the permissive form without changing behaviour — a claim that is now pinned by a
test instead of asserted in a PRD.
