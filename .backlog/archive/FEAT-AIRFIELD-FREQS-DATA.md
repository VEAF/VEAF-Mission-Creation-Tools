# Lot FEAT-AIRFIELD-FREQS-DATA — bundle DCS airfield ATC frequencies per theatre

Status: ✅ done
Branch: feat/airfield-freqs-data → PR → develop

> Lot 2/3 of the convert-v5 preset-aliasing plan. Prerequisite for
> [FEAT-CONVERTV5-FREQ-ALIASING](FEAT-CONVERTV5-FREQ-ALIASING.md) (lot 3).
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

---

## 01 — Radio.lua parser → airfield-frequencies.yaml

Status: ✅ done
Type: feat

### Context

`Mods/terrains/<Theatre>/Radio.lua` holds each airfield's ATC radios. Format (per
airfield entry in the `radio = { … }` list):

```lua
radio = {
  { radioId = ..., role = {"ground","tower","approach"},
    callsign = { {["nato"]={...}}, {["ussr"]={...}} },
    frequency = { [HF]={AM,val}, [UHF]={AM,val}, [VHF_HI]={AM,val}, [VHF_LOW]={AM,val} } },
  ...
}
```

Band mapping to VEAF: `UHF → uhf`, `VHF_HI → vhf`, `VHF_LOW → fm` (HF ignored).

### Tasks (TDD)

- [ ] Failing test first: parse a fixture `Radio.lua` (a couple of airfields incl.
      Batumi) → `{airfield_name: {uhf, vhf, fm}}`, verifying Batumi = 260 / 131 / 40.4.
- [ ] Parser resolves the airfield display name (via the callsign / the existing
      `airdromes.yaml` name↔id mapping) and picks the tower/primary radio's freqs.
- [ ] Emit a canonical `airfield-frequencies.yaml` fragment for one theatre
      (`theatre → airfield → {uhf, vhf, fm}`); MHz as numbers, missing band omitted.

### Definition of Done

- Parser + emitter unit-tested against a fixture; Batumi values verified.
- `ruff`/`mypy`/`pytest` green; coverage gate respected.

---

## 02 — Integrate into `update-dcs-data` + bundle the artifact

Status: ✅ done
Type: feat

### Context

The parser (ticket 01) must run for every installed theatre and its output must ship
with the tools so `convert-v5` (lot 3) can read it without a DCS install.

### Tasks

- [ ] Wire the parser into `veaf-build update-dcs-data`: iterate the installed
      `Mods/terrains/*` theatres (same discovery as `--airdromes`), write the merged
      `airfield-frequencies.yaml` (all theatres, versioned/header-stamped).
- [ ] Bundle `airfield-frequencies.yaml` for the packaged tools: add it to the
      PyInstaller `datas` **and** to `veaf_build/worker.py`'s extra-data list — mirror
      how `dcs-radio-layouts.yaml` is bundled (FIX-VEAF-BUILD-RADIO-LAYOUT-DATA), with a
      regression test on the extra-data list.
- [ ] Loader helper (bundle path + `importlib.resources` fallback), like the radio
      specs/layouts loaders in `presets_manager`.
- [ ] Developer doc: note the new datamine output in `doc/developer` where
      `airdromes.yaml` / radio specs are documented.

### Definition of Done

- `update-dcs-data` regenerates `airfield-frequencies.yaml` across installed theatres.
- The artifact is bundled (test asserts it is in the packaged data list).
- `ruff`/`mypy`/`pytest` green.
