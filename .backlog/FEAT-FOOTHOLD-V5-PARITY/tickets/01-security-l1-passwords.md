# 01 — `security`: set passwords at L1, not just L9

Status: ✅ done
Type: fix

## Why

See the [PRD](../PRD.md), gap 1. `security.password_hashes` emitted `veafSecurity.password_L9`
only, and L9 is the weakest level: the gates that matter — marker authentication
(`checkPassword_L1`), the sensitive spawns (`veafSpawnCore:142`), transport missions — accept
**L1 or L0 only**. A mission configured through `mission.yaml` therefore had a password that
could not authenticate a marker, whatever it was set to.

The hand-written v5 missions set both levels for exactly this reason.

## Also: the documented hash algorithm was wrong

`MISSION_YAML_REFERENCE` said **SHA-256** and gave `e3b0c442…` as the example — which is the
SHA-256 of the empty string. But `veafSecurity._checkPassword` computes `sha1.hex(password)`.
So every hash produced by following the documentation could never match, and the mission looked
protected while being wide open. Confirmed the other way round too: `sha1("veaf_foothold_2026")`
is exactly the `2a4efd…` in David's v5 file.

## Tasks

- [x] Emit `password_L1` **and** `password_L9` for each `password_hashes` entry.
- [x] Leave `password_mm_hashes` in its own `password_MM` table (no level cascade — it is
      checked by `checkPassword_MM` alone).
- [x] Tests: both levels emitted; MM stays out of the cascade.
- [x] Fix the algorithm in `MISSION_YAML_REFERENCE` (FR + EN): SHA-1, with a working example, a
      warning that the page used to say SHA-256, and commands to generate one.
- [x] Document that `password_hashes` reaches L1 and L9.
