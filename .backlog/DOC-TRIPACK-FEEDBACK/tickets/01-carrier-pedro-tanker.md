# 01 — Document auto-generated Pedro & S3B-Tanker (carrier ops)

Status: ✅ done

## Context

`veafCarrierOperations.lua` (l.113–115, 341–520) auto-manages, per registered
carrier, two named support groups it looks up by name:

- `<carrier group name> Pedro` — rescue helicopter (SH-60B), positioned 250 ft high,
  1 nm to the starboard side, riding along at the carrier's speed/heading.
- `<carrier group name> S3B-Tanker` — emergency recovery tanker, 8000 ft, 10 nm aft
  and 4 nm to starboard, refueling on BRC.

Both are respawned when destroyed and their routes are (re)laid by the module. If the
group is absent, the module logs a warning (`No Pedro group named …` /
`No Tanker group named …`). Naming is the only wiring — no script call, no `mission.yaml`.

## Tasks

- [x] Add a section (e.g. "Pedro et ravitailleur S3B" / "Pedro and S3B recovery tanker")
      to `doc/mission-maker/scripts/veafCarrierOperations.md` and `.en.md` explaining:
      the exact naming convention (`<carrier unit name> Pedro`,
      `<carrier unit name> S3B-Tanker`), that groups are auto-detected, respawned and
      routed, the placement expectations (helo type / tanker), and the warning logged
      when a group is missing.
- [x] Cross-link from the module's "Activation" / "Voir aussi" as appropriate.

## Definition of Done

- FR and EN docs describe the naming convention and behaviour; markdown-lint clean.
- No source file touched.
