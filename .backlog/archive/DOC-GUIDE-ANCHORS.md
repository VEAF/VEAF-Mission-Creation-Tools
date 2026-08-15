# DOC-GUIDE-ANCHORS

Status: ✅ done

## Problem

The `# Doc:` links in a generated `mission.yaml` (from `convert-v5`) did not resolve:

- `.../mission-maker/GUIDE#build-profiles` — **missing the trailing slash**, so the site
  redirects `GUIDE` → `GUIDE/` and drops the `#fragment`.
- The anchors were **English** (`#build-profiles`, …) while the published FR GUIDE
  auto-slugifies its FR headings (`#profils-de-build`, …), so they pointed at nothing.

The doc is bilingual (MkDocs Material + `mkdocs-static-i18n`): FR at
`/dev/mission-maker/GUIDE/`, EN at `/dev/en/mission-maker/GUIDE/` (confirmed by curl).

## Decision (option C, validated by David)

Give the five linked headings **stable explicit anchors, identical across FR and EN**,
so one anchor set works for both languages and survives a heading reword:

| Generator anchor | FR heading | EN heading |
|---|---|---|
| `#build-profiles` | Profils de build | Build Profiles |
| `#configuring-modules` | Configurer les modules | Configuring Modules |
| `#configuration-examples` | Exemples de configuration | Configuration Examples |
| `#ctld-and-csar-integration` | Intégration CTLD et CSAR | CTLD and CSAR Integration |
| `#debug-logging` | Changer le niveau de log | Switching log levels |

## Implementation

- `mkdocs.yml`: enable `attr_list` (so `## Title {#id}` declares an explicit id).
- `doc/mission-maker/GUIDE.md` + `GUIDE.en.md`: add `{#…}` to the five headings (same ids).
- `v5_converter._build_mission_yaml`: `_DOC_BASE` is now **language-aware** (EN under
  `/en/`) and ends with a **trailing slash**; the per-section anchors were already the
  English ids, so only the base changed.
- Verified with a local `mkdocs build`: the rendered FR and EN GUIDE carry
  `id="build-profiles"` etc.

## Out of scope

- The report footer `DOC_LINKS` (already anchor-less `GUIDE/`, not broken).

---

## 01 — Stable explicit GUIDE anchors + language-aware Doc links

Status: 🔄 in-progress

### Tasks

- [ ] `mkdocs.yml`: add `attr_list`.
- [ ] GUIDE.md + GUIDE.en.md: explicit `{#…}` on the 5 linked headings (identical ids).
- [ ] `_build_mission_yaml`: language-aware `_DOC_BASE` (EN under `/en/`) + trailing slash.
- [ ] Tests: FR link has `GUIDE/#build-profiles`; EN link uses `/dev/en/…/GUIDE/#…`;
      both GUIDE files declare every generator anchor.
- [ ] CHANGELOG; PATCH bump.

### Definition of Done

- `poetry run pytest` green; ruff/mypy clean; `mkdocs build` renders the explicit ids.
