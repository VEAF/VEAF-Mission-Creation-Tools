# 06 — Modules and community scripts

Status: ✅ done

Type: docs · Files: `doc/mission-maker/build-messages/modules.md` + `.en.md`

## What it is

The family with the most evidence behind it: `builder.ctld_no_config` alone is named in four
backlog lots, two of which (`DOC-CTLD-TOOLS-DOWNLOAD`, `FIX-DEFAULT-COMMUNITY-NOISE`) exist purely
because readers could not tell whether the message meant they had broken something.

Messages: `builder.ctld_no_config`, `builder.ctld_no_config_by_default`,
`builder.ctld_logistics_unmanaged_and_empty`, `builder.ctld_logistics_merged`,
`builder.community_sounds_missing`, `validate.tum_zones_missing`, `validate.incompatible_module` /
`builder.incompatible_modules`, `builder.mandatory_module_enable`, `builder.orphan_lua_module`.

## What it has to carry, beyond the message text

- **Community scripts are opt-out.** That single fact explains most of this page: a module can be
  in your mission although `mission.yaml` never mentions it, which is exactly why a warning about
  it reads as an accusation.
- **The two CTLD messages are different situations** with different right answers — you asked for
  CTLD and have no config, versus you never asked for CTLD at all.
- **TUM aborts at start-up** without its territory zones, so this warning is the only notice you
  get before the module is simply absent in game.
- **What it is not.** None of these mean a module failed to load, and `builder.ctld_no_config_by_default`
  means nothing is wrong at all.

## Definition of done

- [x] Both languages, in the `nav` with `nav_translations`
- [x] One explicit anchor per message, derived from its locale key
- [x] The opt-out default is stated once, up front, and linked from the messages that depend on it
- [x] `poetry run docs-check` passes
