# 05 — Persistence, victory and reset

Status: ⬜ ready

## Persistence

- The campaign state (per zone: owner, drawn garrison, losses; the side scores if any) is written every
  N seconds and on mission end to `lfs.writedir() .. "Missions/Saves/<campaign name>.lua"` with `io`
  — both available on the production install (measured 2026-10-03; `os` is not).
- The file carries a **format version** and the campaign's zone list; on load, a zone renamed or removed
  from `campaign.yaml` is dropped with a warning, a new zone starts from its declared state.
- Without `io`/`lfs` (a sanitized install), the campaign runs without persistence and says so once in the
  log and to admins — never a crash.
- Written atomically (temporary file then rename) so a server killed mid-write keeps the previous state.

## Victory and reset

- `victory: all_zones` or `key_zones`: announced to everyone, the campaign freezes.
- Reset: an admin radio command (secured, `veafSecurity`) deletes the state; the next mission start is a
  fresh campaign.

## Done when

Tests cover save/load round trip, version mismatch, renamed zone, missing `io`, atomic write; one in-game
reading that a restart restores a captured zone.
