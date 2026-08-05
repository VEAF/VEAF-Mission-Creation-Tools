# 09 — translations written straight into the checklist

Status: ✅ done — 2026-08-02.

A mission maker writing their own checklist has no way to make it bilingual. The labels are catalog
keys, the catalog is `veafI18n.lua`, and that file belongs to the framework — adding entries to it
means forking the VEAF scripts. Plain text in the YAML works and is documented, but it is one
language only.

A `custom_scripts` doing `veaf.i18nCatalog["my.key"] = {...}` would fix half of it: right in game,
wrong in the picture, because the image is rendered at **build** time from `published/` and never
sees a mission's own scripts. The PNG would show the raw key.

## The shape

`label` and `title` accept a mapping as well as a string:

```yaml
steps:
  - label: {fr: MAIN PWR sur BATT, en: MAIN PWR switch to BATT}
    element: PTR-ELEC-TMB-MPWR-510
    confirm: true
```

Three accepted forms, and the first two are exactly what they are today:

| Written | Meaning | Resolved |
|---|---|---|
| `label: assist.f16c.main_pwr_batt` | catalog key — what the shipped checklists use | at **runtime**, by `veaf.t()` |
| `label: MAIN PWR sur BATT` | plain text, one language | nowhere; it passes through |
| `label: {fr: …, en: …}` | inline translations | at **build**, in the mission's language |

**A first draft proposed a sidecar `checklists/labels.yaml` with keys instead.** David asked why the
languages could not simply go in the YAML, and he is right: for six steps the sidecar only adds a
second file, an indirection and keys to invent and keep unique, and it buys mutualisation nobody has
asked for. The PRD's "no inline `{fr:…, en:…}`" was justified by ADR 0006 — which governs the
**framework's** catalog, maintained by us and shared across modules. A mission maker's own checklist
is not that case.

## Resolved at build, not at runtime

A mapping is resolved when the mission is built, in the mission's language — the same language the
picture is rendered in. Emitting the whole table into Lua and letting `veaf.t()` choose would create
a case where the picture says one thing and the message another; there is only ever one language per
mission (`veaf.config.language`), so there is nothing to gain.

A **string** keeps today's behaviour and is emitted untouched, so a catalog key stays a catalog key
and is still resolved in game.

Fallback for a mapping: the mission's language, then French (`veaf.I18N_DEFAULT_LANGUAGE`), then any
entry — a label is better shown in the wrong language than as `nil`.

## Rules to enforce

An empty mapping, a non-string value, or an empty string in it is a build error, named as usual.
A mapping whose keys are all unknown languages is not an error — the fallback covers it — but the
loader logs it, since it is almost always a typo (`gb:` for `en:`).

## Tests

`test_checklist_format.py`: the three forms parse; a mapping resolves to the mission's language,
falls back to French then to anything; the rejection rules above. `test_checklist_images.py`: a
mapping is rendered in the mission's language, not as `{fr=…}`. Emission: a mapping becomes a plain
Lua string, a key stays a key.

## Definition of done

- The three forms work end to end, in both display modes.
- Documentation in both languages shows the table above.
- `src/defaults/mission-folder/mission.yaml` needs no change (the option lives in the checklist file).
