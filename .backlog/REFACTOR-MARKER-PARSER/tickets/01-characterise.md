# 01 — Characterise the parsers before touching them

Status: ⬜ ready
Type: test

## Why first

Ten parsers have ten sets of quirks and some are load-bearing. Replacing them without pinning what
they do today turns a refactor into a behaviour change nobody can review — the diff would show a
parser deleted and a parser added, and no reader could tell which differences were intended.

## Scope

Group A (the six `markTextAnalysis`) and group B (the four loops under other names). Group C is
out of scope for the whole lot; see the PRD.

## Tasks

- [ ] For each parser in groups A and B, tests covering: a well-formed command, a keyword with no
      value, a keyword with a non-numeric value, an unknown keyword, an empty command, and the
      keyphrase absent.
- [ ] Extend the quirk inventory below with what the tests reveal, rather than normalising
      anything on the spot.
- [ ] Note anything that looks like a defect. Do **not** fix it here — a characterisation test
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

## Acceptance criteria

- [ ] Every group A and group B parser has tests that pass **before** any refactoring starts.
- [ ] The inventory above is complete, with deliberate quirks separated from accidental ones.
