# 01 — `campaign.yaml`, validation and build generation

Status: ⬜ ready

A sidecar `campaign.yaml` next to `mission.yaml` (ADR 0016's model: the campaign owns its format, it is
large, and the next lot's MCP actions edit it), enabled by a `CAMPAIGN` module in `modules:`.

## The format (first cut, to be confirmed while writing it)

```yaml
campaign:
  name: Caucasus Front
  victory: all_zones            # or key_zones
size_classes:                   # overridable defaults shipped with the tools
  small:  { sam: 0, shorad: [0, 2], aaa: [0, 2], armor: [0, 2], infantry: [1, 3] }
  airfield: { sam: [0, 1], shorad: [1, 3], aaa: [1, 3], armor: [1, 3], infantry: [2, 4] }
zones:
  - name: Kobuleti
    at: { airfield: Kobuleti }  # or { point: <named point> } or { lat: …, lon: … }
    size: airfield
    side: blue
  - name: Alpha
    at: { lat: 42.12, lon: 41.98 }
    size: small
    side: red
    garrison: [sa8, zu23, T-72]   # optional: replaces the random draw
    key: true
connections:
  - [Kobuleti, Senaki]
  - [Senaki, Alpha]
```

## Validation (`veaf-tools mission validate`)

Unknown airfield or point, duplicate zone, connection to an unknown zone, a graph that is not connected,
a garrison alias unknown or absent from the mission's era, a size class with an empty draw, a key zone
missing when `victory: key_zones`. Each with a message in both locales.

## Build

- Trigger zones generated in the `.miz` (one per campaign zone, radius from the size class).
- Dynamic slots enabled at every airfield/FARP zone, for both sides (ownership filters them at run time,
  ticket 03).
- `campaign` rendered as a Lua table loaded before `veafCampaign.lua` (the `veafCities.lua` model).
- The random draw happens **at run time**, not at build: a fresh campaign is not the same twice.

## Done when

Worker/manager split respected, typed, tested (TDD), `validate` and `build` covered; the module documented
in `MISSION_YAML_REFERENCE` (FR/EN); `pyproject` ratchets respected.
