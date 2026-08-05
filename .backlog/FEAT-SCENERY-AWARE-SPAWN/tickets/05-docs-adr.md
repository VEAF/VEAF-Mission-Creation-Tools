# 05 — Docs + ADR 0018 on depending on an undocumented DCS API

Status: ✅ done
Type: docs
Files: `docs/adr/0018-*.md`, `doc/LUA_API_REFERENCE.{md,en.md}`, `docs/exploration/TUM-EXPLOIT.md`, `CHANGELOG.md`

Depends on: 01 (its measurements are the ADR's evidence), 02, 03, 04

## The ADR

Next free number is **0018**. The decision to record is not "use `Disposition`" — it is
**under what conditions VMCT is willing to depend on an undocumented DCS API**, with this as the
first case. Worth an ADR for the same reason [ADR 0017](../../../docs/adr/0017-no-live-mission-editor-bridge.md)
was written: to stop the question being reopened from scratch, in either direction.

Content:

- **Context** — `land.getSurfaceType` is the only scenery signal the documented API offers, and it
  cannot distinguish a wheat field from a village. TUM found a native singleton that can.
- **Decision** — depend on it, but only behind a guard that degrades to the documented behaviour, and
  only for *quality of placement*, never for correctness. Nothing may become unavailable because
  `Disposition` is missing.
- **Consequences** — a DCS patch can remove it silently; the mock covers both branches so CI keeps
  telling us the fallback still works; the standard is now set for the next undocumented find (the
  author mentions others).
- **Rejected alternative** — hand-rolled scenery avoidance from `world.getAirbases` / map objects.
  Say plainly why: DCS exposes no queryable building or forest layer to the mission environment,
  which is precisely why the singleton is valuable.

If ticket 01 came back **negative**, the ADR still gets written — as a recorded dead end, with the
measurements, so the next reader does not repeat the probe.

## Documentation

- [x] `doc/LUA_API_REFERENCE.md` **and** `.en.md`: `veaf.findSpawnPointAwayFromScenery`, the three
      zone-property accessors, and the `veaf.doNotAvoidScenery` switch. Both files, in step — a
      missing EN version is exactly what `DOC-AUDIT-PASS` found and `docs-check` now refuses.
- [x] `docs/exploration/TUM-EXPLOIT.md`: fold ticket 01's measurements in, mark the 🟢 tier
      delivered, and leave the 🔴 tier untouched for `PERSISTENCE`.
- [x] `ROADMAP.md` §4: annotate `TUM-EXPLOIT` with the 🟢 tier shipped and the lot reference, the way
      the `DCS-SMS-EXPLOIT` row records its two closed items.
- [x] `.backlog/README.md` status updated; `docs/adr/` index if one exists.

## Acceptance criteria

- [x] `docs-check` green — no broken link, no dead anchor, no untranslated page, no nav orphan.
- [x] Anchors used in cross-page links are the **explicit English** ones stamped by
      `DOC-QUALITY-GATE`, not heading-derived slugs.
- [x] CHANGELOG entry under `[Unreleased]`; PATCH bump in `pyproject.toml`; `poetry install` run.
