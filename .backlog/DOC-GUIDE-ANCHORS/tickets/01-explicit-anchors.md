# 01 — Stable explicit GUIDE anchors + language-aware Doc links

Status: 🔄 in-progress

## Tasks

- [ ] `mkdocs.yml`: add `attr_list`.
- [ ] GUIDE.md + GUIDE.en.md: explicit `{#…}` on the 5 linked headings (identical ids).
- [ ] `_build_mission_yaml`: language-aware `_DOC_BASE` (EN under `/en/`) + trailing slash.
- [ ] Tests: FR link has `GUIDE/#build-profiles`; EN link uses `/dev/en/…/GUIDE/#…`;
      both GUIDE files declare every generator anchor.
- [ ] CHANGELOG; PATCH bump.

## Definition of Done

- `poetry run pytest` green; ruff/mypy clean; `mkdocs build` renders the explicit ids.
