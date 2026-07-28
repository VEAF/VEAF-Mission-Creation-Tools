# Lot DOC-AUDIT-PASS — full documentation audit: coverage, correctness, both languages, no orphans

Status: ✅ done
Branch: fix/DOC-AUDIT-PASS

## Problem Statement

Requested audit of the whole published documentation: is anything missing (especially the latest
work), is anything wrong (especially what we just changed), is it clear, is it present in both
languages, and are there orphan pages in any menu.

## Method

Everything below was checked **against the published site** (`veaf.github.io/documentation/dev/`)
rather than inferred from the sources, because two plausible-looking defects turned out to be
false positives:

- **232 "EN pages linking to the FR version"** — `mkdocs-static-i18n` rewrites relative links, so
  the published EN page serves `href="veafCombatZone/"`, resolved inside `/en/`. Not a defect.
- **13 "broken anchors"** — `pymdownx.slugify(case=lower)` **keeps accents**, so
  `#étape-1--préréglages-radio-presetsyaml` is a valid id. Only a naive ASCII slugifier makes them
  look broken.

Both were verified by reading the real `id="…"` and `href="…"` values from the live HTML.

## Findings and fixes

| # | Finding | Verified how | Fix |
|---|---------|--------------|-----|
| 1 | `mission-maker/dcs-radio-specs` had **no EN version** — the EN URL returned 200 and served French ("Spécifications", "Appareils critiques"). Worse since FIX-PRIMARY-FREQ-HUMANRADIO added a whole section to it | live page | wrote `dcs-radio-specs.en.md` (85 aircraft rows on both sides, no French left) |
| 2 | 6 links to `../adr/*.md` **404 in production** — `docs/adr/` is not in `docs_dir: doc/` | live 404 | switched to the GitHub blob URL, the convention every other page already used |
| 3 | `MISSION_YAML_REFERENCE` pointed at `#étape-4--variantes-météo…` / `#step-4--weather…`; the pipeline steps were renumbered and that is now step **6** | live anchor list | repointed (FR + EN) |
| 4 | `MISSION_YAML_REFERENCE` pointed at `#intégration-ctld-et-csar`, which never existed — the section carries the stable anchor `ctld-and-csar-integration` | live anchor list | repointed |
| 5 | `LUA_API_REFERENCE` documented `veafRadio.addSubMenu(title, parentMenu)` — stale since FEAT-COMBATZONE-MENU-COALITION added the `coalitionSide` parameter | source | documented the third parameter and its inheritance rules (FR + EN) |
| 6 | Same page pinned **Version 6.5.25 / June 2026** while shipping 6.11.8 | source | "generated for 6.11.x" + July 2026 — a range nobody has to bump per patch |
| 7 | The `veafRadio` module page never mentioned coalition-scoped menus, the day's new capability | source | new section in both languages, cross-linked with `veafCombatZone` |
| 8 | `developer/capture-airbases` was reachable only through a link from `dcs-data` — absent from every menu | nav diff | added under Developer, with its FR nav translation |
| 9 | The sections added today were linked by **guessed slugs** | — | gave them explicit English anchors (`red-side-zone`, `f10-menu-audience`, `primary-frequency`), per the DOC-GUIDE-ANCHORS convention |

Deliberately left alone: `assets/img/README.md` (a repo note on image layout, correctly outside the
menu) and `ALIASES.md` appearing twice in the nav (once per audience — intentional).

## Verification

After the fixes, over all 95 pages: **0** broken relative links, **0** dead cross-page anchors,
**0** FR page without an EN counterpart (bar the repo note), **0** nav entry pointing at a missing
file, **0** page outside the nav (same exception).

## Out of Scope

The reorganisation proposal itself — reported to David as a separate answer, not implemented here.
