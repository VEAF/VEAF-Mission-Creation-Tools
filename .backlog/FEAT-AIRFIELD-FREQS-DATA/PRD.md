# Lot FEAT-AIRFIELD-FREQS-DATA — bundle DCS airfield ATC frequencies per theatre

Status: ✅ done
Branch: feat/airfield-freqs-data → PR → develop

> Lot 2/3 of the convert-v5 preset-aliasing plan. Prerequisite for
> [FEAT-CONVERTV5-FREQ-ALIASING](../FEAT-CONVERTV5-FREQ-ALIASING/PRD.md) (lot 3).
> Lot 1 (FEAT-CONVERTV5-PLAN-PRESETS, ADR 0010) is done.

## Problem Statement

`convert-v5` presets carry **hardcoded ATC frequencies** for airfields (e.g. Batumi
UHF 260 / VHF 131 / FM 40.4). To later reverse-lookup a frequency back to a readable
airfield name (lot 3), VEAF needs a data source mapping `<theatre> → airfield →
{uhf, vhf, fm}`. DCS ships these in `Mods/terrains/<Theatre>/Radio.lua` (**not**
`Beacons.lua`, which only carries ILS/TACAN/VOR/homer beacons). VEAF already
datamines the same terrains folder (`airdromes.yaml` from `Beacons.lua` via
`veaf-build update-dcs-data --airdromes`) but not the ATC radio frequencies.

## Solution

Extend `veaf-build update-dcs-data` to parse `Mods/terrains/<Theatre>/Radio.lua` for
every installed theatre and emit a **bundled, versioned** `airfield-frequencies.yaml`
(`theatre → airfield → {uhf, vhf, fm}`). Bundled at build time (David validated
bundled over on-the-fly), so `convert-v5` needs no DCS install at conversion time.

Mapping from the Radio.lua `frequency` block: `UHF → uhf`, `VHF_HI → vhf`,
`VHF_LOW → fm` (HF ignored). Example: Batumi → `uhf 260 / vhf 131 / fm 40.4` — matches
today's default `presets.yaml` `channels_collection`.

## Decisions (validated by David)

- **Bundled + versioned** artifact, not read from the user's DCS at convert time.
- Reuse the existing `update-dcs-data` datamine plumbing (same terrains folder as
  `airdromes.yaml`).
- Ship the maintained theatre set (Caucasus, Syria, PersianGulf, Sinai, Normandy,
  MarianaIslands, GermanyColdWar, …) — whatever the datamine finds installed.

## Scope

- **Ticket 01** — `Radio.lua` parser → model + `airfield-frequencies.yaml` emitter;
  unit tests on a fixture `Radio.lua` (Batumi et al.).
- **Ticket 02** — wire into `veaf-build update-dcs-data` (multi-theatre) + **bundle**
  the artifact (PyInstaller `datas` + `veaf_build/worker.py` data list, exactly like
  `dcs-radio-layouts.yaml` — see FIX-VEAF-BUILD-RADIO-LAYOUT-DATA) + developer doc.

## Out of scope

- Consuming the data / any convert-v5 change — that is lot 3.
- ATC beacons (TACAN/ILS/VOR) — already in `airdromes.yaml`.
