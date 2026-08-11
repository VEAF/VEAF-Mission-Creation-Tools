# 02 — Decide whether the tier names change

Status: ✅ done — option 2, renamed with deprecated aliases; **the by-name path and its warning were left unwired and were finished by ticket 03 on 2026-08-11** (see below)
Type: chore

## The state of it

```lua
veafSecurity.LEVEL_L0 = 90
veafSecurity.LEVEL_L1 = 10
veafSecurity.LEVEL_L9 = 1
```

A check passes when the pilot's level is **at least** the constant, so `L9` is the loosest tier
and `L0` the tightest. That is self-consistent if the names denote *password* tiers with `L0` as
the most secret. It is the exact opposite of what a reader assumes from "level 0" and "level 9",
and it was the opposite of what `doc/mission-maker/GUIDE` claimed until 2026-08-06.

## Why this is a decision and not a fix

The names are **public API for mission makers**: they appear in marker text, in
`mission.yaml` password blocks, and in the `veafSpawn.registerCommandHandler` calls of any
third-party script. Renaming them breaks missions. Leaving them keeps a trap that has already
caught someone once — the agent writing `SECREV-2` ticket 03 offered David "L0 — all players"
from the (then wrong) documentation, and taking the answer literally would have locked a
deliberately public command to administrators.

## The options

1. **Keep the names, keep the corrected documentation.** Zero breakage. The trap survives, now
   signposted with a warning admonition on the guide page.
2. **Rename to what they mean** — e.g. `PILOT` / `SENIOR` / `ADMIN` — with the old names kept as
   deprecated aliases for a release. Costs a migration and a deprecation window; ends the trap.
3. **Renumber so the order matches the names.** Rejected before it is proposed: it silently
   changes what every existing mission's passwords protect, which is the one outcome nobody can
   detect from the outside.

## Tasks

- [ ] Put options 1 and 2 to David with the migration cost of each.
- [ ] If renaming: aliases, a deprecation warning at registration, and a `convert-v5`-style note
      for mission makers.
- [ ] Either way, one place in the code carries the authoritative explanation, and the guide
      links to it rather than restating it — restating it is how the two drifted apart.

## Acceptance criteria

- [ ] The chosen option is recorded with its reason, so this is not re-opened by the next reader
      who finds the ordering surprising.
- [ ] Code and documentation state the same thing, from one source.

## Finished by ticket 03 — 2026-08-11

Measured while ticket 03 looked for the deprecation precedent this ticket was supposed to have set:
**`LEVELS_BY_NAME` and `DEPRECATED_LEVEL_NAMES` had no reader.** Neither, anywhere in the tree.

The rename shipped and works — callers write `veafSecurity.LEVEL_ADMIN` and the alias constants
resolve to the same values — so nothing was broken. What was missing is the **by-name** resolution, the
path a config string or a YAML tier name would take, and with it the deprecation warning that
`DEPRECATED_LEVEL_NAMES` exists for.

Worse, the comment above the aliases asserted that `veafSecurity.registerCommandHandler` warns when a
deprecated name is used. There is no such function — `registerCommandHandler` lives in `veafCommands`.
A comment describing a mechanism that does not exist is how this stayed invisible.

`veafSecurity.levelForName(name)` is that wiring now, with 9 tests. The misleading comment is
corrected rather than removed, so a reader learns it was wrong.

**Left for ticket 01**: `checkSecurity_L0/L1/L9` still read `veafSecurity.LEVEL_L0/L1/L9`. The
repository has not migrated off the names it deprecates, so the aliases cannot be dropped in v7 until
those three functions move.
