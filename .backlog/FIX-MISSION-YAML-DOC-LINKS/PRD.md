# FIX-MISSION-YAML-DOC-LINKS — the `# Doc:` links in a generated `mission.yaml` do not resolve

Status: 🔄 in-progress

Origin: David, 2026-09-22, while reviewing PR #986 (FIX-CSAR-YAML-SETTINGS). Pre-existing and
deliberately left out of that PR's scope.

## Problem

Every `# Doc:` comment `generate-config` writes into a `mission.yaml` is dead, in two independent
ways.

### 1. The wrong site

The links point at the **GitHub blob view**:

```
https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/master/doc/mission-maker/GUIDE.md#...
```

GitHub renders markdown without MkDocs' `attr_list` extension, so a heading written
`## Intégration CTLD et CSAR {#ctld-and-csar-integration}` shows up with the literal `{#…}` **as
part of the heading text**, and its slug becomes `intégration-ctld-et-csar-ctld-and-csar-integration`.
The explicit anchor is not an id GitHub serves, and neither is the plain heading slug. No anchor in
these links can work there.

The published documentation site is where the anchors are real. Measured 2026-09-22 with `curl` on
`https://veaf.github.io/documentation/dev/mission-maker/GUIDE/`: the page serves
`id="build-profiles"`, `id="configuration-examples"`, `id="configuring-modules"`,
`id="ctld-and-csar-integration"`, `id="debug-logging"` and `id="security-tiers"` — and none of the
French slugs the links use.

The repository had already settled this for the *other* `mission.yaml` generator: `convert-v5`
(`mission_builder/v5_converter.py`) builds its `# Doc:` links from
`DOC_BASE = "https://veaf.github.io/documentation/dev"`, language-aware, with a trailing slash, and
`test_v5_converter.py` even asserts `blob/master/doc` is absent from its output. That was lot
DOC-GUIDE-ANCHORS. The `generate-config` path — `veaf_libs/lua_config_generator.py`, driven entirely
by the `generated.mission_yaml.*` message keys — was never touched. Same bug, second code path.

### 2. Heading-derived anchors

`CLAUDE.md` is explicit: *"Never link a heading-derived slug: it breaks on the next reword and
differs between FR and EN."* Seven of the links do exactly that.

| key | current anchor | explicit anchor the page declares |
|---|---|---|
| `section.cap` (fr) | `#exemples-de-configuration` | `#configuration-examples` |
| `section.combat` (fr) | `#exemples-de-configuration` | `#configuration-examples` |
| `section.qra` (fr) | `#exemples-de-configuration` | `#configuration-examples` |
| `section.external` (fr) | `#intégration-ctld-et-csar` | `#ctld-and-csar-integration` |
| `section.modules` (fr) | `#configurer-les-modules` | `#configuring-modules` |
| `section.pipeline` (fr) | `#profils-de-build` | `#build-profiles` |
| `section.global_log_level` (fr) | `#journalisation-de-débogage` | `#debug-logging` |
| `section.security` (fr) | `#niveaux-de-sécurité` | `#security-tiers` |
| **`section.security` (en)** | **`#security-levels`** | **`#security-tiers`** |

Two of these are worth naming separately, because they are the failure mode `CLAUDE.md` warns about,
caught in the act:

- **`#journalisation-de-débogage` is stale.** The FR heading has since been reworded to *"Changer le
  niveau de log"*. The slug was already wrong before anyone thought about the anchor convention.
- **`en.json` is not clean either.** `#security-levels` is the slug of the English heading *"Security
  Levels"*, not the explicit id `{#security-tiers}` that heading declares. English happening to look
  like an English anchor is exactly what makes this one easy to miss.

### 3. Nothing catches it

`docs-check` walks `doc/`. It never opens a locale JSON file, so a documentation URL embedded in a
message key is unguarded — which is how a dead anchor survived DOC-GUIDE-ANCHORS and reached every
`mission.yaml` a mission maker generates.

## What to build

**a. Point the links at the documentation site**, matching what `convert-v5` already does:
`https://veaf.github.io/documentation/dev/mission-maker/GUIDE/` for `fr.json`, and
`.../dev/en/mission-maker/GUIDE/` for `en.json`. Trailing slash before the fragment — without it the
site redirects and drops it (DOC-GUIDE-ANCHORS again).

**b. Use the explicit anchors**, identical in both languages.

**c. Add the missing gate**: a test that extracts every documentation URL from `locales/*.json`,
resolves it back to its markdown page, and asserts the page declares that anchor **explicitly**. It
also rejects a GitHub blob link into `doc/`, since no anchor can work there.

## Out of scope

- `builder.ctld_no_config` → `https://github.com/VEAF/CTLD/releases` is a release page, not
  documentation, and stays a GitHub link.
- `src/defaults/mission-folder/mission.yaml` already carries the site URL in its header and declares
  no anchored link, so the §9.7 defaults lockstep needs no change here.

---

## 01 — Documentation links that resolve, and a gate that keeps them resolving

Status: 🔄 in-progress

### Tasks

- [ ] `fr.json` / `en.json`: move the nine `generated.mission_yaml.*` doc links to the published
      site, language-aware base, trailing slash.
- [ ] `fr.json` / `en.json`: replace every heading-derived anchor with the explicit one.
- [ ] `test_i18n.py`: new gate over `locales/*.json` — every doc URL resolves to a page, every
      fragment is an **explicit** anchor of that page, the language segment matches the catalog, and
      no doc link goes through the GitHub blob view.

### Definition of Done

- `poetry run pytest` green; `ruff check` / `ruff format --check` / `mypy` clean.
- The new gate fails when an anchor is reverted to its heading-derived form (checked by hand before
  committing).
- `CHANGELOG.md` entry under `[Unreleased]`, appended at the end.
