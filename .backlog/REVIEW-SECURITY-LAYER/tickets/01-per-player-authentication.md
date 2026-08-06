# 01 — Make authentication per-player instead of global

Status: ⬜ ready
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
