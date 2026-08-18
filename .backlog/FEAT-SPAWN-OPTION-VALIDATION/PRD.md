# FEAT-SPAWN-OPTION-VALIDATION — a mistyped option is silently ignored

Status: ⬜ ready

Origin: [#33](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/33), open since 2021.

## The gap

`veafSpawnParser.lua` has **no unknown-option path** — grepped for "unknown option", "invalid" and
"unrecognized": zero. A marker whose option is misspelt spawns something, just not what was asked,
and the pilot cannot tell "I typed it wrong" from "the feature does not do that".

It is the same failure mode as the silent losses `FIX-CONVERT-V5-SILENT-LOSSES` closed, one layer up:
the tool does something plausible instead of saying it did not understand. And it covers **every**
marker command at once, since `REFACTOR-MARKER-PARSER` gave them a single parser.

## Scope

Collect unrecognised keys while parsing and name them on screen, with the command. Do **not** refuse
the whole command: a pilot mid-flight would rather have the spawn plus a warning than nothing at all.

## Definition of done

- [ ] An unknown option is named on screen, the recognised ones still applying
- [ ] Every marker command benefits, not only `_spawn`
- [ ] Tests: an unknown option is reported, and valid options are never reported (the witness)
