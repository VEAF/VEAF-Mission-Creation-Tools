# veafI18n — The in-game message catalogue

**Module ID:** `I18N` | **File:** `veafI18n.lua`

---

## Purpose

Holds **the translation catalogue** for the messages VEAF scripts show players: **263 keys**, each in
French and English. French is the default language (`veaf.I18N_DEFAULT_LANGUAGE`).

This module holds data only. The lookup function, `veaf.t(key, ...)`, lives in `veaf.lua` — and that
is deliberate: it must stay available even when the catalogue is not loaded.

This page is for **developers**.

---

## How a translation is resolved {#lookup}

`veaf.t("spawn.did_you_mean", "sa6")` looks, in order, for:

1. the entry in the configured language (`veaf.config.language`);
2. the same entry in **French**, the default language, when the translation is missing;
3. **the key itself**, when the entry does not exist at all.

That third step is what makes a missing message show up on screen as `spawn.did_you_mean` instead of
crashing the script. If you see a raw key in game, that entry is absent from the catalogue.

Extra arguments go through `string.format`, **under `pcall`**: a format that does not match its
arguments yields the unformatted text rather than a DCS error.

---

## Adding a message {#add-a-message}

```lua
["my.module.message"] = {
  fr = "Le groupe %s est arrivé",
  en = "Group %s has arrived",
},
```

Then, in the module: `trigger.action.outText(veaf.t("my.module.message", groupName), 10)`.

**Both languages are mandatory** — an i18n coverage test refuses a key carrying French only, and
another refuses a string hard-coded in a module. Today all 263 keys have both.

The naming convention is `<module>.<subject>` in lower case, for example `spawn.unknown_parameters` or
`groundai.cannot_aim`.

---

## Choosing a mission's language

```yaml
mission:
  language: fr      # fr | en — defaults to the tooling's language
```

---

## `mission.yaml` configuration

No options of its own. It always loads.

---

## See also

- [mission.yaml reference](../../MISSION_YAML_REFERENCE.en.md) — the `mission.language` field
- [Developer guide](../../developer/GUIDE.en.md) — the i18n coverage tests
