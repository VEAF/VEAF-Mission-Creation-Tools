# FEAT-AWACS-ESCORT-COMMANDS — `-awacs` and `-escortme`

Status: 🧑 waiting-human — code, tests and docs done (2026-10-04); waits on its in-game check, R41 in `DCS-SESSION-TODO.md`. Unblocked 2026-10-03: Mission D of `CHORE-ISSUE-VERIFY-SESSION` answered both escort bugs — #107 confirmed then fixed by `FIX-ESCORT-RESPAWN-DISTANCE` (verified in game, R5), #101 not reproducible; both issues closed

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

## Decisions (David, 2026-10-04)

The plan was put to David as five points; his answers, and what they mean in the code.

- **a — the AWACS is built from its type, not from a template.** No reference mission holds a `veafSpawn-` AWACS template, so a template-based `-awacs` would have failed in every mission. `veafAircraftSpawn.AWACS_TYPES` lists the four DCS types carrying the `AWACS` attribute, with their fuel and countermeasures; a Python test compares it with `dcsUnits.yaml`.
- **b — Skynet on by default, as #188 asks**, with `skynet false` to keep it out. `INVESTIGATE-SKYNET-AWACS-BLIND` stays open; the doc says what to try when a mission's SAMs stay dark with an AWACS up.
- **c — both entries, but not as first proposed.** The F10 menu escorts the pilot's own group (*Escort me*, per group, known-pilot level). The marker is **`-escort`**, not `-escortme`, and takes no target name: it escorts the friendly or neutral airplane nearest the marker, within 10 NM.
- **d — the DCS `Escort` task**, the mechanism `veafMove` already repairs on a move or a respawn; not the CAP watchdog around the escorted aircraft. The escort's ROE is set to `OPEN_FIRE` after the template's options.
- **e — the in-game check goes on the session list** (R41).

## Tickets

1. [`-awacs`](tickets/01-awacs-command.md) — ✅
2. [The `air_escort` role and `-awacs, escort`](tickets/02-air-escort-role.md) — ✅
3. [`-escort` and *Escort me*](tickets/03-escort-commands.md) — ✅
4. [In-game check](tickets/04-in-game-check.md) — 🧑 R41

## Definition of done

- [x] #101 and #107 answered before any escort code is written
- [x] `-awacs` spawns an AWACS with the right task, Skynet and datalink on by default (on the mocks; R41 in game)
- [ ] `-escort` and *Escort me* escort an airplane — **and defend it**, verified in game rather than
      assumed from the spawn succeeding
- [x] Both documented, both languages

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**`-awacs` and `-escortme`** (#188 + #189), grouped since both spawn a group with a predefined mission. **Blocked on the DCS session, deliberately**: #101 and #107 say the escort mechanism may be broken — a teleported escort stops defending, a respawned one does not follow — so shipping `-escortme` on top would hand a pilot a **decorative** escort that appears, formates and defends nothing. The command would look delivered and be useless, the same shape as everything else closed this month. The AWACS half does not depend on that bug and can ship first
