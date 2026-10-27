# FIX-FATCOW-CTLD-FARPS — GRASS leaves CTLD's Fat Cow FARPs alone, and the CH-47F gets CSAR

Status: 🔄 in progress

Origin: the evening server run of CTLD's Fat Cow (VEAF/CTLD#273, Privé 1, 2026-10-26, Zip, Griffin, Paluche), findings 3 and 5 of its ticket 06.

## Problem

- **GRASS made a Fat Cow unlimited.** A Fat Cow is a CH-47 that opens a FARP whose warehouse holds what the cow carries. `veafGrass.onBirth` calls `fillAllFarpWarehouses` on every player birth, which refills every FARP, the cow's included: two packs read back 50 035 and 50 055 kg of fuel from a cow that carried 7 200.
- **No CSAR menu in the CH-47F.** `csar.aircraftType` lists no `CH-47Fbl1`, so CSAR gives the Chinook no menu in any VMCT mission.

## Change

- `veafGrass.fillAllFarpWarehouses` skips any airbase whose name starts with `CTLD_`: CTLD names its Fat Cow FARPs `CTLD_FatCow_FARP_<n>` for this. CTLD also guards its own stock since #273, but a refill run before CTLD reads hides what was taken since its last read.
- `csar.aircraftType["CH-47Fbl1"] = 24`, a VEAF adaptation of the vendored `CSAR.lua`, recorded in `vendored.yaml`.

## Tickets

- [01 — GRASS skips CTLD FARPs, CH-47F in CSAR](tickets/01-grass-skips-ctld-farps.md)
