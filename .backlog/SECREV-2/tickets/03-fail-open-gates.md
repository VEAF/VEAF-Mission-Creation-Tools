# 03 — Security gates that fail open

Status: ⬜ ready
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
