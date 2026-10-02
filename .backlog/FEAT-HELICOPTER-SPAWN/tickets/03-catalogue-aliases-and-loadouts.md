# 03 — Catalogue aliases and loadouts

Status: ✅ done

Lot: [FEAT-HELICOPTER-SPAWN](../PRD.md)

## What changes

- `veaf-units.yaml` unit aliases may carry `pylons` (station → `{CLSID}`), copied from the shipped
  `dynamic-slot-templates.yaml`. An alias with pylons is **armed**.
- The spawn-data emitter renders those pylons, and a `veafUnits.AircraftPayloads` table — fuel, chaff and
  flare per helicopter type, from `dcsUnits.yaml` (`M_fuel_max`, `passivCounterm`). The runtime has no
  fuel data of its own, and an aircraft created without fuel falls (`aircraft_payload.py`).
- Shipped aliases: `mi8` (Mi-8MT), `mi26` (Mi-26), `uh1` (UH-1H), `ch47` (CH-47Fbl1) unarmed; `mi24`
  (Mi-24P), `ka50` (Ka-50_3), `ah64` (AH-64D_BLK_II), `gazelle` (SA342M) armed, with their template's pylons.

## Done when

- The emitter tests cover the pylons and the payload table; a test pins that every shipped helicopter
  alias gets a fuel load above zero.
