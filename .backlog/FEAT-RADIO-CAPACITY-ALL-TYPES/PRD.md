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
| 01 | [Read every module's preset counts](tickets/01-read-panel-radio.md) | ✅ |
| 02 | [Declare them, default FM list to 20](tickets/02-declare-and-default.md) | ✅ |

Python, TDD. One branch, one PR.

## Outcome — 2026-11-10

### Where the counts come from (D2, D3)

D2 asked for a script reading the `panelRadio` tables of a DCS install. The repository already had one source for them: `veaf_build/radio_specs_updater.py` parses `panelRadio` from the Quaggles datamine to write `dcs-radio-specs.yaml`, at a pinned ref, with a CI job regenerating it on every PR.
The datamine dumps DCS's runtime `db`, so each radio's `channels` list is already flattened — a module Lua that builds it in a loop is no trap — and the pin is **DCS 2.9.31.29434**, the version installed on David's machine (`autoupdate.cfg`, 2026-11-10).
So the generator now counts the `channels` of each radio and writes `channels: <n>` per radio into `dcs-radio-specs.yaml`; it is refreshed with the rest of the radio data by `veaf-build update-dcs-data --radio` after a pin bump, and the build never reads DCS. That meets D2's intent (refreshable, checked in, sourced: the file names its ref) without a second reader and without a DCS install, which the CI and the PwC workstation do not have.

D3: a radio entry in `dcs-radio-layouts.yaml` cannot carry a capacity alone — `role` is mandatory, and an entry replaces the band-based default for the whole type. So the count lives in the specs, and the packer takes it when the layout declares no `capacity` (layout wins), under the band-based default too.

Checked against #1262's hand reading: OH58D 20/20/21/21, Mi-24P 20/10, CH-47Fbl1 20/20/10, AJS37 47 — identical, so the layout values stay; `test_the_shipped_layout_capacities_agree_with_the_modules` fails if a DCS update moves one.

### Coverage (D1)

The injector iterates the types of `dcs-radio-specs.yaml` (`get_radios`): **87 of the 100 get a count on every radio.** The 13 others have none:

| Types | Why |
|---|---|
| A-10A, F-15C, J-11A, MiG-29A, MiG-29G, MiG-29S, Su-25, Su-25T, Su-27, Su-33 | Flaming Cliffs: no `panelRadio` in the datamine; `kneeboard_only`, never injected anyway |
| La-7, MiG-15bis, MiG-15bis_FC | Their radio is declared by `dcs-radio-specs-overrides.yaml`; the datamine lists no channels for it |

### The cut goes by slot number

`_truncate_to_capacity` compared the **count** of channels with the capacity and renumbered the kept ones 1..n. Lists have gaps — a channel dropped out of band leaves its slot empty so a pilot's channel N stays N (the default A-10C UHF list: 15 channels up to slot 19) — so a short list could reach past the last slot, and a cut would have shifted the kept channels. It now drops the channels whose slot is past the capacity and leaves the others where they are; on a gapless list it is the same cut.

### No change for what fits (D4)

Packed for both coalitions and the 100 types, with `presets_assignments` applied, before and after, on the shipped defaults (30-entry list) and the eight OT `presets.yaml`: **328 presets change, every one by the channels past a radio's last slot and nothing else**; all the others are identical. `test_the_shipped_defaults_change_only_by_the_cut` keeps it on the shipped defaults (the OT repositories are not in CI).

### Default lists (D5)

`fm_supplement` cut to its first 20 entries: the OH-58D FM radios (21 slots: C + M + 1..19) and the A-10C/A-10C II FM radio (20) no longer lose a preset.
**D5's "no capacity warning" does not hold once every type has a count**, measured on the 122 (coalition, type) pairs of the shipped templates: 29 warnings, all on lists the module cannot hold whatever their length, reported here and not cut (D5):

| Radio | Holds | Dropped (shipped lists) |
|---|---|---|
| P-51D, P-51D-30-NA, TF-51D, P-47D-30, P-47D-40 radio 1 / radio 2 | 4 / 1 | 4 / 14 |
| FW-190A8, FW-190D9, Bf-109K-4, SpitfireLFMkIX radio 1 | 5 | 3 |
| I-16 | 4 | 4 |
| F4U-1D, F4U-1D_CW radio 1 / radio 2 | 4 / 6 | 11 / 2 |
| MosquitoFBMkVI radios 1-4 | 5 / 8 / 8 / 8 | 3 / 12 / 12 / 9 |
| MiG-19P | 6 | 2 |
| AH-64D_BLK_II radios 2 / 3 / 4 | 10 | 7 / 10 / 10 |
| F-4E-45MC radio 1, F-86F Sabre | 18 | 1 |

Those presets were never selectable in the cockpit; the kneeboard listed them. The OTs give the same kind of list: 32 (Normandy) to 66 warnings each when packed for all 100 types; a mission only warns for the types it carries.

The `mission.yaml` defaults lockstep is not concerned: only `presets.yaml` changed.

### Left out

- `presets_assignments` (the manual path) is not capped: the shipped blue CH-47F gets `radio_fm_30`, 30 FM presets on an ARC-186 that holds 20 (D6 keeps that list out). Known limitation `radio-capacity-not-applied-to-manual-presets`.
- Whether the warbird and AH-64D warnings are worth their noise is left to David: they name presets no cockpit could select.

## Where it stands — 2026-11-10, stopped for the night

Done on `feature/radio-capacity-all-types` (pushed, no PR): generator `channels` count + regenerated `dcs-radio-specs.yaml`, packer default capacity + slot-number cut, tests (incl. the D4 test on the shipped defaults, checked to fail under a renumbering cut), `fm_supplement` at 20, docs fr/en, ADR 0010 amendment, layouts comment, known limitation, CHANGELOG. The ticket statuses say ✅ for the code; the lot stays 🔄 until merged.

Left to do:
1. Quality gate: `ruff check`, `ruff format --check`, `mypy`, full `pytest` (only `test/python/presets_injector/` and the radio-specs tests ran), `docs-check`; bump `--cov-fail-under` if coverage allows.
2. `pr-code-review` (full) on the diff against `origin/develop`.
3. On merge: move the lot from `ACTIVE.md` to `DONE.md`, update the counts in `README.md`, set Status ✅.
4. Open the PR (`--base develop`) carrying the D5 table above, then `gh pr merge --auto --merge`.
