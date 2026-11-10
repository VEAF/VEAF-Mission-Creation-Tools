# FEAT-RADIO-CAPACITY-ALL-TYPES — Every aircraft's radios declare their preset capacity

Status: 🔄 in-progress

Follow-up of FIX-RADIO-PRESET-CAPACITY (#1262, merged 2026-11-10), agreed by David the same day ("ok" to both recommendations).

## The need

#1262 found that a radio's preset count is written in its module, in the `panelRadio` table of the aircraft's Lua (`C:\jeux\DCS World\CoreMods\aircraft\<type>\<type>.lua` for the four types it read; some modules may live under `Mods\aircraft\`).
It declared a `capacity` for the only four types `dcs-radio-layouts.yaml` lists (OH-58D, Mi-24P, CH-47F; AJS-37 filled by construction).
Every other type in the catalogue has no capacity: the injector writes whatever the list holds, and a module that crashes past its count — as the OH-58D did with 32 FM presets — is found only in game.

#1262 also measured that the shipped default `fm_supplement` (`src/defaults/mission-folder/src/presets.yaml`) holds 30 entries: every build from the defaults now truncates the default blue Kiowa's FM radios, with 2 warnings per build.

## Decisions — 2026-11-10

| # | Question | Decision |
|---|---|---|
| D1 | Which types | Every aircraft type the presets injector can write radios for (the types of `dcs-radio-specs.yaml`, or whatever list the injector actually iterates — read it from the code). A type whose module has no readable `panelRadio` keeps no capacity, and the Outcome lists it |
| D2 | How the counts are read | A script under `veaf_build/` or `tools/` that reads the modules' `panelRadio` tables from a DCS install and writes the counts, so the table can be refreshed after a DCS update; the counts are checked in, the build never reads DCS. Each count carries its source (module file) |
| D3 | Where they live | Where the injector already reads `capacity` (`dcs-radio-layouts.yaml`). If a radio entry there cannot carry a capacity alone without changing the radio's layout, say so and choose the smallest change that keeps today's output byte-for-byte for the types that do not overflow |
| D4 | No change for what fits | A mission whose lists fit every radio is byte-for-byte what it was (test on the shipped defaults and on a sample of OT `presets.yaml`) |
| D5 | Default `fm_supplement` | Cut to **20 entries** in `src/defaults/mission-folder/src/presets.yaml`, keeping the first 20. A build from the defaults then raises no capacity warning (measured). Any other default list that overflows a newly declared capacity is reported in the PR, not cut, unless it is the same case as the FM one |
| D6 | Out of scope | The channels themselves, the CH-47's own `radio_fm_30` list, the OTs' `presets.yaml` |

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [Read every module's preset counts](tickets/01-read-panel-radio.md) | ⬜ |
| 02 | [Declare them, default FM list to 20](tickets/02-declare-and-default.md) | ⬜ |

Python, TDD. One branch, one PR.
