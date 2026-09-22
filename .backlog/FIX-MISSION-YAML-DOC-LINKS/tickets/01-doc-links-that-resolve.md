# 01 — Documentation links that resolve, and a gate that keeps them resolving

Status: ✅ done

Type: fix

## What to build

### The links

The nine `generated.mission_yaml.*` keys that carry a `# Doc:` URL move from the GitHub blob view to
the published documentation site, and drop every heading-derived anchor.

`fr.json` base: `https://veaf.github.io/documentation/dev/mission-maker/GUIDE/`
`en.json` base: `https://veaf.github.io/documentation/dev/en/mission-maker/GUIDE/`

The trailing slash is load-bearing: without it the site redirects `GUIDE` → `GUIDE/` and the browser
drops the fragment on the way.

| key | anchor |
|---|---|
| `generated.mission_yaml.header` | *(none)* |
| `generated.mission_yaml.section.cap` | `#configuration-examples` |
| `generated.mission_yaml.section.combat` | `#configuration-examples` |
| `generated.mission_yaml.section.qra` | `#configuration-examples` |
| `generated.mission_yaml.section.external` | `#ctld-and-csar-integration` |
| `generated.mission_yaml.section.modules` | `#configuring-modules` |
| `generated.mission_yaml.section.pipeline` | `#build-profiles` |
| `generated.mission_yaml.section.global_log_level` | `#debug-logging` |
| `generated.mission_yaml.section.security` | `#security-tiers` |

The anchors are identical in both catalogs — that is the whole point of an explicit id.

### The gate

A new test over `src/python/veaf-tools/veaf_libs/locales/*.json`. For every URL found in any string
value:

- a `github.com/VEAF/VEAF-Mission-Creation-Tools/blob/…/doc/…` link **fails** — GitHub renders
  `{#anchor}` as heading text, so no anchor written there can resolve;
- a documentation-site URL resolves back to its markdown source (`…/mission-maker/GUIDE/` →
  `doc/mission-maker/GUIDE.md`, or `.en.md` under the `/en/` segment) and that file must exist;
- its language segment must match the catalog the URL was found in — `en.json` under `/en/`,
  `fr.json` at the root;
- its fragment, when present, must be an **explicit** `{#anchor}` of that page. `anchors_of()` from
  `veaf_build.docs_check` already returns the explicit set separately, so the heading-derived slug is
  rejected without re-implementing a slugifier.

Links outside the documentation site (release pages and the like) are ignored.

## Done when

- `poetry run pytest` is green, and the new gate is proven to **fail** when one anchor is put back to
  its heading-derived form — a gate nobody has seen fail is not a gate.
- `ruff check`, `ruff format --check`, `mypy` clean.
- `CHANGELOG.md` has an entry under `[Unreleased]`, appended at the end.
