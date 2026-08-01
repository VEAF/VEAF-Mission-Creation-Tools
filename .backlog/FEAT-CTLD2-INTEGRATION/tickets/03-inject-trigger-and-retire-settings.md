# 03 — inject the config trigger, retire `settings:`

**Status:** ✅ done

Depends on 02.

## What changes

**Injection.** A MISSION START trigger, ordered **before** the one loading `CTLD.lua`, containing:

```lua
ctld = ctld or {}
ctld.dontInitialize = true      -- VEAF calls ctld.initialize() itself (PRD decision 5)
ctld.configUser = [==[ …the mission's ctld-config.yaml, verbatim… ]==]
```

Pick the long-bracket level defensively: the YAML can contain `]]`. Only inject when the CTLD module
is enabled **and** the mission carries a `ctld-config.yaml`; when the file is absent, still inject
`dontInitialize` alone — VEAF owns the init either way.

**`lua_config_generator`.** Delete the CTLD block
([lua_config_generator.py:1380-1388](../../../src/python/veaf-tools/veaf_libs/lua_config_generator.py)):
no more `ctld.<key> = value`, no more `ctld.initialize()`. The `external_modules["ctld"]` internal
representation keeps only `enabled`. CSAR and Skynet are untouched — they still use that channel.

**`mission.yaml`.** `CTLD:` becomes a plain boolean. Remove the
`# extended: CTLD -> { enabled: true, settings: … }` comment from
[src/defaults/mission-folder/mission.yaml](../../../src/defaults/mission-folder/mission.yaml) — the
defaults-lockstep rule of `CLAUDE.md` §9.7 — and replace it with a pointer to `ctld-config.yaml`.

**`validate`.** A `CTLD:` entry carrying `settings:` is an **error**, not a warning and not a silent
ignore: "CTLD 2 is configured in `ctld-config.yaml` (edit it with ctld-tools) — `settings:` is no
longer read." A warning would reproduce exactly the silent-overwrite failure this lot removes.
Both message strings go in `locales/fr.json` and `locales/en.json`.

## Acceptance

- A built `.miz` shows, in order: the config trigger, then `CTLD.lua`, then the rest.
- A `ctld-config.yaml` containing `]]` round-trips intact.
- `CTLD: {enabled: true, settings: {hoverPickup: true}}` fails `validate` with the new message.
- `CTLD: true` alone builds and runs.

## Tests

- unit: trigger ordering in the produced `.miz` (the existing MISSION START injection tests cover the
  index-shift machinery — reuse it, do not re-invent).
- unit: bracket-level escalation on a payload containing `]]`.
- unit: `lua_config_generator` emits nothing CTLD-related, and still emits CSAR/Skynet.
- unit: the `validate` rule, FR and EN.
