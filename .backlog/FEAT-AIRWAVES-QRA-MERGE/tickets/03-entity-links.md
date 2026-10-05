# 03 — link a zone to entities (#183)

Status: ✅ done — 2026-10-05
Type: feature

`links:` on a QRA definition and on an air-wave zone: names of airbases, FARPs, ships, groups or statics the zone depends on.
Decided 2026-10-05: an airbase or FARP captured or under its minimum life **pauses** the zone, which resumes when it is retaken — today's `airport_link` behaviour, unchanged; a ship, group or static destroyed **stops** the zone for good, since nothing brings it back.
Any one lost link is enough. `airport_link` stays read as a one-entry shortcut.
