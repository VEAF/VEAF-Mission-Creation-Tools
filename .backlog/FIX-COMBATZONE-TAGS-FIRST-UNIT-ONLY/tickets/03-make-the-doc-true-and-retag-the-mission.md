# 03 — Make the documentation's group-name promise true, and stop the verification mission dodging the case

Status: ✅ done
Type: fix

Depends on [01](01-read-the-tags-off-every-name.md).

## Documentation

`doc/mission-maker/scripts/veafCombatZone.md` (and `.en.md`) claim unit **and group** names carry tags,
which was false. Ticket 01 makes it true, so the pages need the rule stated rather than the claim left
implicit:

- where the tags are read from, and the fixed source order;
- what happens when two names disagree;
- that `#command` stays attached to the object carrying it, and what a `#command` on a group name means.

## Verification mission

`test/veaf-tools/verify-mission-a` set its `#alarm=2` check up by tagging **both** M-1 Abrams of the
group, precisely to dodge this defect — so the in-game pass on 2026-08-18 proved nothing about the
single-unit case. Re-tag one Abrams only, so the mission proves the case instead of avoiding it.

## Definition of done

- [x] Both language pages state the rule, the source order and the conflict behaviour
- [x] `poetry run docs-check` passes
- [x] `verify-mission-a` carries `#alarm=2` on exactly one of the two Abrams
- [x] The mission's README says what the check now proves
