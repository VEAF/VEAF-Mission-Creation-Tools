# 02 — The 77 entries, and the guard that forbids the next literal

Status: ✅ done 2026-08-13 — 77 entries through veaf.t, 48 keys; the enumerating guard found 31 labels a line-by-line sweep had missed
Type: fix
Files: `src/scripts/veaf/veafI18n.lua`, the 11 modules building menu entries, `test/lua/`

## The change

71 static entries and 6 composed ones move to `veaf.t`, keyed `menu.<module>.<entry>`:

```lua
veafRadio.addCommandToSubmenu(veaf.t("menu.combatmission.get_info"), …)
veafRadio.addCommandToSubmenu(veaf.t("menu.assets.respawn", element.description), …)
```

The 6 composed ones take a `%s`, so word order stays translatable — `"Respawn " .. name` cannot become
correct French by concatenation.

**English wording changes in exactly one place**, per David's arbitration b: `Desactivate zone` and
`Desactivate mission` become `Deactivate …`. Everything else keeps its current English string, so a
reviewer comparing the English side sees a rename and nothing more.

## The guard

A test that **enumerates every `veafRadio.add*` call from the module sources** and fails when the first
argument is a string literal. Not a sample: the same rule that made
`FIX-MARKER-PARAM-CRASHES-2`'s sweep trustworthy. Prove it discriminating by injecting a literal and
watching the test name it.

The guard is what makes the fix durable — 90 labels drifted in precisely because nothing forbade the
91st.

## Careful

- `veafWeather`'s fog entries build their titles from generated constants
  (`veafWeather["FOG_ANIMATED_" .. minutes .. "M_NO"].name`). Those names are **data on the preset
  object**, not menu literals: they need their own decision, and the honest one may be to leave the
  preset names alone and translate only the submenu titles around them. Read the code before deciding,
  and say what was decided.
- `veafCombatZone` has 18 entries, some built per zone and per tasking order. Check which are per-zone
  data (a zone's friendly name is authored by the mission maker and must **not** be translated).

## TDD

- Failing first, per module: build the menu with `language = "fr"` against a recording stub and assert
  the French label appears; then `en`.
- Failing first: the enumerating guard reports every remaining literal, and reports nothing once the
  conversion is done.

## Acceptance criteria

- [ ] No `veafRadio.add*` first argument is a literal; the guard proves it and is discriminating.
- [ ] i18n coverage green (both languages for every new key).
- [ ] `test-lua` + stylua green.
