# 04 — a zone that follows a unit (#186)

Status: ✅ done — 2026-10-05
Type: feature

Decided 2026-10-05: both ways.
A trigger zone the mission editor linked to a unit (`linkUnit`, which `edit_zone` also writes) follows that unit; a centre-and-radius zone follows the unit named by `follow_unit:`.
The centre is read again on every check and every spawn. A dead unit leaves the zone where it last was (03 can stop it).
