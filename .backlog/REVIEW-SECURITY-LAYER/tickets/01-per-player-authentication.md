# 01 — Make authentication per-player instead of global

Status: 🔄 in-progress — **the mechanism is built and tested; the global short-circuit that bypasses it is still in place.** Measured 2026-08-11, see *State, measured* below. What remains is wiring plus one decision, not design
Type: feat

## The problem, measured

`veafSecurity.authenticated` is a single boolean on the module table. It is written in exactly
four places (`veafSecurity.lua` lines 56, 518, 536, 661) and read through
`veafSecurity.isAuthenticated()`, which every `checkSecurity_Lx` calls **before** anything else:

```lua
function veafSecurity.checkSecurity_L9(password, markId)
  if veafSecurity.isAuthenticated() then return true end   -- <-- global, for everybody
  ...
```

One `/login` by one player therefore opens every secured command to every player on the server
for `authDuration`. It also means the per-player path — the pilot level the hook publishes from
`veaf-pilots.txt` — is never reached while anyone is logged in, so the precise mechanism is
disabled by the blunt one whenever the blunt one is in use.

## Why it is not simply "make it a table keyed by player"

The check has no idea who is asking. `checkSecurity_L9(password, markId)` receives a mark id,
and recovers an author from it only for the *level* lookup. On the paths that pass no `markId`
at all — `checkSecurity_MM`, and every caller that passes `nil` — there is no identity to key on.

So this is a signature change across the security surface, not a data-structure swap, and the
call sites have to supply an actor. Two candidate sources, both already present:

- the mark panel's `author` (a display name, matched case-insensitively — what
  `getMarkerSecurityLevel` uses today);
- `Event.initiator` → unit name → `veafRemote.getRemoteUserFromUnit` (a UCID-backed identity,
  and the sounder of the two — see finding 3 in the PRD).

## Tasks

- [ ] Establish which entry points can supply an actor and which genuinely cannot; the ones that
      cannot decide the shape of the fallback.
- [ ] Decide with David what a logged-in session should mean: one player, one player in one slot,
      or a UCID for a duration.
- [ ] Change `isAuthenticated` and the `checkSecurity_*` family to take an actor, keeping the
      no-actor case **fail-closed** rather than falling back to the global flag.
- [ ] Migrate the F10 radio menu's two `isAuthenticated` sites (`veafRadio.lua`), which gate
      secured menu commands and have a different notion of "who" — the menu is per-group.
- [ ] Tests: one player logging in does not authenticate another; a logged-in player's session
      does not survive a slot change if the decision above says it should not.

## Acceptance criteria

- [ ] No code path grants a second player access because a first one authenticated.
- [ ] Every `checkSecurity_*` either knows who is asking or denies.
- [ ] The behaviour change is written down for server admins: this **will** stop working the way
      VEAF staff currently rely on, and that has to be announced rather than discovered in flight.

## State, measured 2026-08-11

The design was settled with David days ago and **is implemented**. Re-measured against the code
rather than read off this ticket's unchecked boxes, which is what misled me into presenting it as an
open question:

| Piece | Where | State |
|---|---|---|
| markers resolve to the panel's **author** and their level | `getMarkerSecurityLevel` | ✅ |
| a group's level is the **minimum** of its human occupants | `getGroupLevel` | ✅ |
| an occupant with no known level yields 0 | same | ✅ — otherwise omitting people would raise a group |
| `_auth elevate` raises a group, **capped at the requester's own level** | `elevateGroupForPilot` | ✅ |
| 2-minute bound on an elevation | `ELEVATION_DURATION_SECONDS = 120` | ✅ |
| the F10 menu consults the effective group level | `veafRadio.lua:297` | ✅ |

### What is still open is one line, in four places

```lua
function veafSecurity.checkSecurity_L0(password, markId)
  if veafSecurity.isAuthenticated() then   -- the global boolean, before anything else
    return true
```

`checkSecurity_L0/L1/L9` each open with it, and `veafShortcuts` has three more
(`:339`, `:427`, `:520`). So the fine-grained mechanism is built, tested, and **short-circuited by
the blunt one** exactly as this ticket described. One `/login` still opens everything to everyone.

`checkSecurity_MM(password)` is separate: it takes **no `markId` at all**, so it has no identity to
key on. This ticket wants that case fail-closed.

### These four are one change, not four

Removing the short-circuit does **not** break password access — `checkPassword_Lx(password)` stays in
the condition, so "your level suffices OR you give the password" still holds. What it removes is the
*convenience*: today one `_auth <password>` buys ten minutes during which no command asks again.

So the short-circuit cannot simply be deleted; it has to be **replaced** by the group elevation, and
that is why the four sites move together.

## The design that follows, and the one open question

Two authentication paths exist, and both can already reach a group:

| Path | Identity available | Proposed translation |
|---|---|---|
| `login` over chat/remote (`veafSecurity.lua:530`) | `_pilot.level` **and** `_unitName` | elevate the pilot's group to the pilot's own level — literally `handleElevationRequest`, which already exists |
| `_auth <password>` on a marker (`:570`) | the password proves a **tier**; `executeCommand` receives `markerAuthor`, so the group is reachable | elevate the author's group to the tier the password proved, for `authDuration` |

**The open question is the elevation ceiling.** David described it as *"max(pilotes du groupe) si
`_auth` ou `/login`"*. The code caps at the **requester's own level** instead, with this reasoning in
`elevateGroupForPilot`:

> *Without it, any occupant could raise the group to its most privileged member's level and act with
> rights they were never granted — the bug this lot exists to remove, rebuilt as a feature.*

The two coincide when the highest-graded occupant is the one asking. They differ otherwise: a
`KNOWN_PILOT` in a group where an admin is flying gets `KNOWN_PILOT`, not the admin's rights. **The
code is stricter than the description**, and deliberately. Confirm which is intended before wiring
`_auth` to it, because the wiring is where the choice becomes real.

## Operational impact — has to be announced, not discovered

This ticket already says it and it bears repeating at the point of execution: **this will stop working
the way VEAF staff currently rely on.** Today one login unlocks the server for everyone for ten
minutes. Afterwards it unlocks one group, for two minutes, at one level. That is the point of the lot,
and it is also a change people will feel mid-mission if nobody tells them.
