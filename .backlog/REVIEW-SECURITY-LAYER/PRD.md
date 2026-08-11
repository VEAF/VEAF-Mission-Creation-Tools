# REVIEW-SECURITY-LAYER — the marker security model, revisited on measurements

Status: 🔄 in-progress

Asked for by David on 2026-08-06, while deciding the levels for
[`SECREV-2` ticket 03](../SECREV-2/tickets/03-fail-open-gates.md): *"on pourrait en profiter
pour revoir toute la couche sécu — j'avais fait ça il y a longtemps et j'ai peur que ça ne soit
plus très adapté"*.

The unease is justified, and this lot exists because closing the fail-open holes turned it into
three concrete findings rather than a feeling. **None of them is a reason to hold ticket 03**,
which fixed the mechanism; these are about what the mechanism enforces.

## What is already true, and better than expected

The identity path David wanted — *"limiter ce genre d'actions aux pilotes VEAF, donc ceux qui
sont authentifiés via le hook"* — **already exists end to end**:

`veafSecurity.getMarkerSecurityLevel(markId)` finds the mark panel in `world.getMarkPanels()`,
reads its `author`, resolves that name through `veafRemote.getRemoteUser()` — the table the
server hook fills via `registerUser(name, level, ucid)` from `veaf-pilots.txt` — and returns
that pilot's level. Every `checkSecurity_Lx(password, markId)` already consults it. So a marker
command *can* be restricted to authenticated VEAF pilots today, with no new plumbing. Four
handlers simply never called any check, which is what ticket 03 fixed.

## The three findings

### 1. `veafSecurity.authenticated` is one global boolean

`veafSecurity.isAuthenticated()` returns a single module-level flag, and every
`checkSecurity_Lx` tests it **first**:

```lua
if veafSecurity.isAuthenticated() then return true end
```

So one `/login` by one person unlocks every secured action **for everyone on the server**, until
someone logs out or `authDuration` expires. It also short-circuits the per-player identity path
above before it is ever consulted — the good mechanism is bypassed by the crude one.

This is the finding that most deserves David's original word *"plus très adapté"*: it made sense
when the server was a handful of people on Discord, and does not on a public server.

### 2. The tier ordering contradicted its own documentation

`LEVEL_L0 = 90`, `LEVEL_L1 = 10`, `LEVEL_L9 = 1`, and a check passes when the pilot's level is
**at least** the constant. So `L9` is the *loosest* tier (any listed pilot) and `L0` the
*tightest* (administrator). Coherent if the names are read as password tiers, `L0` being the
most secret — but `doc/mission-maker/GUIDE` stated the exact opposite ("0 (public) — all
players") until ticket 03 corrected it.

That is not a theoretical trap: writing ticket 03, the agent offered David "L0 — all players"
based on the page, he chose it for named points, and taking it literally would have locked a
deliberately public command to administrators. The documentation is now right. **Whether the
names should change is the open question**, and it is a breaking one — mission makers write
these strings.

### 3. Per-unit identity exists and is unused for security

`veafRemote.getRemoteUserFromUnit(unitName)` maps a unit to its pilot, fed by
`registerUserSlot`. Marker events carry `Event.initiator`, and `veafMarkers` reads
`Event.initiator:getName()` **only to log it at trace level**, then discards it. So there are
two ways to identify who acted and the security layer uses the more fragile one — the mark
panel's `author` string, matched by name.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Make authentication per-player instead of global](tickets/01-per-player-authentication.md) | 🔄 |
| 02 | [Decide whether the tier names change](tickets/02-tier-naming.md) | ✅ |
| 03 | [`veafSecurity.SecurityDisabled` was a public config field, retired as dead code](tickets/03-securitydisabled-compat-break.md) | ✅ |

PR #676 delivered ticket 02 in full — the tiers are `ADMIN` / `SENIOR_PILOT` / `KNOWN_PILOT` with deprecated `L0`/`L1`/`L9` aliases — and ticket 01 **in part**: the global boolean no longer short-circuits the per-pilot path, authentication is per group, and an elevation is bounded to the requester's own level. What remains of 01 is the `checkSecurity_*` signatures.

Ticket 03 was found later, on 2026-08-09, by running the converted demo mission in DCS — not by reading the code, which is the point of it.

## What this lot will not do

- **Re-open `SECREV-2` ticket 03's levels.** `veafGroundAI` L9, `veafMove` L1, `veafRadio` L1,
  `veafNamedPoints` OPEN are David's decisions of 2026-08-06 and stand until he changes them.
  If ticket 02 renames the tiers, these move with the rename; they are not re-litigated.
- **Change behaviour without a decision.** Both tickets change who can do what on a live
  server. Each ends in a recorded choice, not an inferred default.
