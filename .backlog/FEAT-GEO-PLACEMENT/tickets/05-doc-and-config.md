# FEAT-GEO-PLACEMENT-005 — Doc + catalogue + skill + config

Status: ✅ done
Type: docs
Files: `doc/`, `plugin/skills/veaf-mission-authoring/SKILL.md`, `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `CHANGELOG.md`, `pyproject.toml`

## What to build

- Document the geocoder: backends (OSM default, Google via key), the **OSM usage policy +
  attribution**, and how to configure a Google API key.
- Catalogue + developer doc: the `geocode` action, place-by-name usage, and the **honest caveats**
  (approximate/confirm-visually; vague unnamed terrain not covered).
- Skill: when the user gives a real-world description, use `geocode` (with bearing/distance for
  "N km from X"), then place with the resulting `xy`; always surface the resolved point.
- CHANGELOG; version bump.

## Acceptance criteria

- [ ] FR + EN docs in sync; attribution + key-config documented.
- [ ] Skill guides place-by-name and surfacing the resolved coordinates.
- [ ] CHANGELOG entry; version bumped.

## Blocked by

FEAT-GEO-PLACEMENT-001..004.
