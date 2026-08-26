---
Status: ✅ done
---

# 03 — Say it loudly when a mission will have no logistics

Two distinct messages, both i18n (`fr.json` + `en.json`), keyed near `builder.ctld_no_config`.

## Do

- **`manage_logistics: false` and both type lists empty** → warning in `validate` **and** in the
  build. It must stand out rather than sit in the middle of the warning list: this mission starts
  with no logistic point from the editor at all. Name the two settings and say the flag is off.
- **`manage_logistics: true` and the merge added at least one type** → one informational build
  line listing them, so a maker can see the injected configuration differs from their file.

Silent in every other case — in particular when the maker owns a non-empty list, which is a
legitimate choice and must not nag on every build.

## Done when

The warning fires on the reported shape (`logisticUnitTypes: []`) with the flag off, and does not
fire with the flag on, or with a non-empty list.
