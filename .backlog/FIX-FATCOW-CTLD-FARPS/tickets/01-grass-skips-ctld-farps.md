# 01 — GRASS skips CTLD FARPs, CH-47F in CSAR

Status: 🔄 in progress

## Done when

- `fillAllFarpWarehouses` never refills an airbase named `CTLD_…` (test `TestVeafGrassFillAllSkipsCtldFarps`).
- `csar.aircraftType["CH-47Fbl1"]` is 24, and `vendored.yaml` lists it among the CSAR adaptations to re-apply.
- In game, with a CTLD build carrying the Fat Cow: a player joining does not refill a deployed cow's FARP, and the CH-47F has the CSAR menu (to check by Zip with CTLD's ticket 06).
