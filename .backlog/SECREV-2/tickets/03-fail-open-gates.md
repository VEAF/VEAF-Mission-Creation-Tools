# 03 — Security gates that fail open

Status: ✅ done — delivered 2026-08-06
Type: fix
Findings: VMR-003 🟠, VMR-004 🟠 (its security half)

## The pattern

`veafCommands.dispatchMarker` deliberately delegates the security decision to each handler. Most
honour it — `veafCasMission` requires L9, `veafTransportMission` L1 — but a handler that simply does
not check is **wide open**, and nothing notices. Forgetting fails open.

Verified 2026-08-05: `veafGroundAI.lua` (VMR-003) contains no reference to `veafSecurity`,
`isAuthenticated`, or any password constant. Its marker commands run for anyone. The SRS path in
`veafRadio` (VMR-004) is the second instance.

## The fix the review argues for, and it is the right shape

Not "add a check to veafGroundAI" — that leaves the next handler free to forget. Make the gate a
**positive obligation**: a shared wrapper that requires a declared security level, so a handler
without one fails closed instead of open.

- [ ] Inventory every marker handler and the level it declares today, including the ones that declare
      nothing. That list is the real finding; VMR-003 is one row of it.
- [ ] A registration path that cannot be used without stating a level. Whether that is an argument
      with no default, or a registry the dispatcher consults, is a design call — but "no level" must be
      impossible rather than permitted.
- [ ] Decide `veafGroundAI`'s level **with David**: it spawns and commands ground AI, so it is not
      obviously L1, and guessing here changes who can do what on a live server.
- [ ] A test asserting that a handler registered without a level is refused, not silently allowed.

## Acceptance criteria

- [ ] No marker handler reaches execution without a declared level.
- [ ] Adding a handler that forgets one fails a test, not a server.
- [ ] Every level assigned in this ticket is recorded with who decided it — these are policy choices
      about a live multiplayer server, not defaults to be inferred.

---

## Delivered 2026-08-06

**The inventory was the finding, exactly as this ticket predicted — and VMR-003 is one row of
four.** Three modules on the marker path had no security check of any kind and only one was
reported:

| Handler | Priority | Before | Now |
|---|---|---|---|
| `veafShortcuts` | 10 | own check | `SECURITY_HANDLED` |
| `veafSpawn` | 20 | per-subcommand | `SECURITY_HANDLED` |
| `veafNamedPoints` | 30 | **none** | `OPEN` |
| `veafCasMission` | 40 | own check (L9) | `SECURITY_HANDLED` |
| `veafSecurity` | 50 | is the login | `OPEN` |
| `veafMove` | 60 | **none** | `L1` |
| `veafGroundAI` | 62 | **none** ← VMR-003 | `L9` |
| `veafRadio` | 70 | **none** | `L1` |
| `veafRemote` | 80 | own check (L9) | `SECURITY_HANDLED` |
| `veafTransportMission` | direct | own check (L1) | unchanged — registers with `veafMarkers`, not here |

`veafRadio` deserves a note: it *does* contain two `isAuthenticated` calls, so a grep for
"does this module check security" answers yes. Both guard the **F10 menu**'s secured commands.
The marker path was open. Counting references would have missed it; reading them found it.

**The second layer had the right design and an escape hatch.** `veafSpawn.registerCommandHandler`
already took a level — and documented a "legacy 2-arg form (key, fn), no security check". Three
commands used it (`smoke`, `flare`, `signal`). They are genuinely meant to be open, so they now
say `"OPEN"`; the 2-arg form is gone, and both layers assert on a missing or unknown level.

**The dispatcher can gate the four newly-declared handlers itself** because none of them parses a
password — verified, not assumed. So the check is on identity alone: the pilot level the server
hook publishes from `veaf-pilots.txt`, which is precisely what David asked for.

**A trap this ticket walked into and left signposted.** The levels were put to David with labels
taken from `doc/mission-maker/GUIDE`, which said `L0` meant "all players". The code says
`LEVEL_L0 = 90` and a check passes at *or above* the constant — so `L0` is the **tightest** tier
and `L9` the loosest. Writing `"L0"` for named points, as the answer literally read, would have
locked a deliberately public command to administrators. Caught before commit; the guide is
corrected in both languages with a warning admonition, and the naming question is
[`REVIEW-SECURITY-LAYER` ticket 02](../../REVIEW-SECURITY-LAYER/tickets/02-tier-naming.md).

## Levels, and who decided them

All four by **David, 2026-08-06**, in answer to a direct question:

- `veafGroundAI` → **L9**. His words: *"limiter ce genre d'actions aux pilotes VEAF, donc ceux
  qui sont authentifiés via le hook"*. In this codebase that population is L9 (level ≥ 1).
- `veafMove` → **L1**. Moving a tanker affects everyone flying.
- `veafRadio` (marker) → **L1**. Transmitting audio on a frequency is spammable.
- `veafNamedPoints` → **OPEN**. Informational, no side effect; open by decision now, not by omission.

## Consequence for existing missions

Three commands that anyone could use now require a pilot level or a login: ground AI, move, and
SRS transmit. On a server with no hook and no pilots file, nobody has a level, so those three
need `/login`. That is the intended change and it needs announcing, not discovering in flight.
