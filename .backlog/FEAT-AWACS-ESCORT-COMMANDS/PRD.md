# FEAT-AWACS-ESCORT-COMMANDS — `-awacs` and `-escortme`

Status: ⬜ ready — unblocked 2026-10-03: Mission D of `CHORE-ISSUE-VERIFY-SESSION` answered both escort bugs — #107 confirmed then fixed by `FIX-ESCORT-RESPAWN-DISTANCE` (verified in game, R5), #101 not reproducible; both issues closed

Origin: [#188](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/188) (`-awacs`) and
[#189](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/189) (`-escortme`). Grouped: both
spawn a group with a predefined mission, and #188 already asks for an escort option of its own.

## What they ask

- **`-awacs`** — spawn an AWACS with the right mission: an `escort <template>` option, Skynet
  integration on by default, EPLRS/datalink on by default.
- **`-escortme`** — spawn an escort for *my* aircraft: `/escort me f15-fox3`, or a named flight.

## Why it waits

**Two open bugs say the escort mechanism may be broken.**
[#101](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/101) (a teleported escort stops
defending itself or its group) and
[#107](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/107) (a respawned escort does not
follow) are both in the DCS verification session, Mission D.

Shipping `-escortme` on top of that would hand a pilot a **decorative** escort: a flight that appears,
formates, and defends nothing. The command would look delivered and be useless — the same shape of
defect as everything else closed this month.

So: run Mission D first. If the escort mechanism is sound, this lot is two commands. If it is not,
fixing it comes first and is the real work.

## Scope

1. Mission D of `CHORE-ISSUE-VERIFY-SESSION` answered for #101 and #107
2. `-awacs`, with the three options #188 lists — the AWACS half does **not** depend on the escort bug
   and can ship first
3. `-escortme`, once an escort is known to work

## Definition of done

- [ ] #101 and #107 answered before any escort code is written
- [ ] `-awacs` spawns an AWACS with the right task, Skynet and datalink on by default
- [ ] `-escortme` escorts the caller's own aircraft — **and defends it**, verified in game rather than
      assumed from the spawn succeeding
- [ ] Both documented, both languages

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**`-awacs` and `-escortme`** (#188 + #189), grouped since both spawn a group with a predefined mission. **Blocked on the DCS session, deliberately**: #101 and #107 say the escort mechanism may be broken — a teleported escort stops defending, a respawned one does not follow — so shipping `-escortme` on top would hand a pilot a **decorative** escort that appears, formates and defends nothing. The command would look delivered and be useless, the same shape as everything else closed this month. The AWACS half does not depend on that bug and can ship first
