# Lot REVIEW-SECURITY-LAYER — the marker security model, revisited on measurements

Status: ✅ done — 2026-08-11. **The global authentication boolean has no readers left.**

Asked for by David on 2026-08-06 while deciding the levels for `SECREV-2` ticket 03: *"on pourrait en
profiter pour revoir toute la couche sécu — j'avais fait ça il y a longtemps et j'ai peur que ça ne soit
plus très adapté"*. The unease was justified, and closing the fail-open holes turned it into three
concrete findings rather than a feeling.

| # | Ticket | Status |
|---|--------|--------|
| 01 | Make authentication per-player instead of global | ✅ |
| 02 | Decide whether the tier names change | ✅ |
| 03 | `veafSecurity.SecurityDisabled` was a public config field, retired as dead code | ✅ |

## What was already better than expected

The per-player identity path David wanted **already existed end to end**:
`getMarkerSecurityLevel(markId)` finds the mark panel, reads its `author`, resolves that name through
`veafRemote.getRemoteUser` — the table the server hook fills from `veaf-pilots.txt` — and returns that
pilot's level. Four handlers simply never called any check, which `SECREV-2` ticket 03 fixed.

## Ticket 01 — one boolean, and the mechanism it disabled

`veafSecurity.authenticated` was a single module-level flag, and every `checkSecurity_Lx` consulted it
**first**. So one `/login` opened every secured command to **every player on the server** for
`authDuration` — and while anyone was logged in, the precise per-pilot path was never reached at all.

The replacement was designed with David and built first: a group acts at the level of its **lowest**-graded
human occupant (an occupant with no known level yielding 0, so omitting people cannot raise a group),
raised to the **requester's own level** for 120 seconds by `_auth` from an identified channel. That last
cap is the safety: without it any occupant could raise the group to its most privileged member's level —
the bug this lot removes, rebuilt as a feature.

> **The subtlety, in David's words**: *"on ne connaît pas le 'demandeur' dans le menu radio, uniquement
> son groupe ; d'où ce subterfuge."* DCS cannot tell which occupant of a group clicked an F10 command, so
> the group is the finest identity that channel offers. An instructor flying with a student keeps their
> own commands by authenticating, without lending the student anything.

**And it was short-circuited by the thing it replaced** — measured 2026-08-11, after I had misread the
ticket's unchecked boxes as an open design question. The mechanism was complete and tested; the boolean
was still first in line. Removing it does not remove password access (`checkPassword_Lx` stays in the
condition); it removes the convenience of one login covering everyone.

The three `veafShortcuts` alias gates were the boolean's last readers, and asked a different question —
an alias password is a per-alias secret with **no tier attached**. David chose option 1: being in
`veaf-pilots.txt` at all excuses it, whatever the level (`veafSecurity.isKnownPilot`).

**Announced, not discovered**: a pilot listed in `veaf-pilots.txt` notices nothing; a pilot who is not
listed must give the password on every command. Documented in both languages, and surfaced at the top of
the changelog for the release notes.

## Ticket 02 — the tier names read backwards, and its warning was never wired

`L0` was the **tightest** tier while reading like the loosest, and the trap had already caught someone: a
proposal read "L0 - all players" off the documentation and would have locked a deliberately public
command to administrators. Renamed to `ADMIN` / `SENIOR_PILOT` / `KNOWN_PILOT`, values unchanged, old
names kept as aliases.

**Finished by ticket 03**, which went looking for the deprecation precedent it was told to copy and found
none: `LEVELS_BY_NAME` and `DEPRECATED_LEVEL_NAMES` had **no reader anywhere in the tree**, and the
comment above the aliases claimed `veafSecurity.registerCommandHandler` emits the warning — **no such
function exists**. The rename worked because callers use the constants directly; the by-name path was
declared and left unwired. `veafSecurity.levelForName()` is that wiring.

## Ticket 03 — three years of missions asking for security off and getting it on

`SECREV-009` moved `isAuthenticated`'s fallback from `veafSecurity.SecurityDisabled` to
`veaf.SecurityDisabled` because the old name was *"never assigned"* — true inside this repository and
false outside it, since it is a **mission-facing config knob** and the only places that assign it are
mission configs. Including our own demo mission.

Fail-safe, which is why it went unnoticed: nobody was over-privileged. But every secured command then
refused for everyone on a mission whose author had deliberately opened them, and a permission denial
reads as *"the security layer is broken"*, not *"your config field was retired"*.

> **The durable lesson, now in the code**: for a config field, "nothing in the repository assigns it" is
> evidence of nothing.

## The defect the wiring exposed

`getMarkerSecurityLevel` indexed `veafRemote` **unguarded**, unlike `getPilotLevelForUnit` three functions
below. Harmless while every caller happened to load that module — and a **raise inside a security check**
as soon as one did not, which widening the callers is exactly what exposed. It returns -1 (unknown author)
now, so the failure mode is a refusal rather than a crashed handler.

Found by the `veafShortcuts` characterisation suite, written the same morning for
`REFACTOR-MARKER-PARSER`, which has nothing to do with security and simply does not load `veafRemote`.
