# FEAT-AWACS-ESCORT-COMMANDS — `-awacs` and `-escortme`

Status: 🧑 waiting-human — blocked on `CHORE-ISSUE-VERIFY-SESSION`, see *Why it waits*.

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
