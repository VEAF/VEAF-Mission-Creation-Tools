# 02 — `_transport` demands the password from everyone, listed or not

Status: ✅ done — the marker id reaches the check; the doc caveat is deleted in both languages
Type: fix
Files: `src/scripts/veaf/veafTransportMission.lua`, `test/lua/test_veafTransportMission.lua`

## The bug

`veafTransportMission.lua:125` calls `veafSecurity.checkSecurity_L1(options.password)` **without
the `markId`**. `getMarkerSecurityLevel(nil)` then returns `-1` (`veafSecurity.lua:775-799`), so
the identity path can never grant anything and a pilot listed as `SENIOR_PILOT` in
`veaf-pilots.txt` — whose level is the whole point of the listing — still has to type the password
on every `_transport`.

Every other marker command passes its marker id and gets the per-player check. This one predates
the per-player model and was never rewired; the audit caught it because `veafSecurity.md`'s claim
("rien ne change pour un pilote listé") is false precisely here.

## Fix

Pass the marker id through to the security check, the way the other marker commands do (read one of
them for the exact call shape rather than assuming).

## TDD

- Failing first: a mocked identified marker author with level ≥ L1 and **no password** must pass
  the `_transport` security gate; an unidentified author without password must still fail.

## Acceptance criteria

- [ ] Listed pilot, no password → `_transport` accepted; unknown author, no password → refused.
- [ ] `test-lua` + stylua green.
- [ ] The caveat `DOC-AUDIT-FIXES` 01 adds to `veafSecurity.md` becomes deletable.
