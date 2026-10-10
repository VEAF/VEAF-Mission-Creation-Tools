# 01 — Campaign folder: `campaign.yaml`, campaign state, validation

Status: ✅ done

Shared brick: the format is reused as is by `FEAT-DYNAMIC-CAMPAIGN`.

A campaign is a folder: `campaign.yaml` (what the author declares, never rewritten by the tools), the **campaign state** (what the campaign has become, rewritten after every mission, versioned), and one sub-folder per mission (its mission folder, its state file, the state before and after).
The history is kept whole so that a mission can be replayed or a merge undone.

## `campaign.yaml` (first cut, to confirm while writing it)

```yaml
campaign:
  name: Caucasus Front
  theatre: Caucasus
  era: MODERN
  missions: 10                  # the strategic objectives are sized to be reachable in about this many
  objectives:                   # what winning means
    - capture: [Senaki, Kutaisi]
    - destroy: { zone: Gudauta, kind: logistics }
size_classes:                   # parameters of veafCasMission's generators; shipped defaults, overridable
  outpost:  { size: 2, defense: 1, armor: 1 }
  airfield: { size: 4, defense: 3, armor: 2, long_range_sam: true }
zones:
  - name: Kobuleti
    at: { airfield: Kobuleti }  # or { point: <named point> } or { lat: …, lon: … }
    size: airfield
    side: blue
  - name: Gudauta depot
    at: { lat: 43.10, lon: 40.58 }
    size: outpost
    side: red
    kind: logistics             # feeds its side's ground reserve (ticket 06)
    garrison: [sa8, shilka, T-72B] # optional: replaces the draw
connections:
  - [Kobuleti, Senaki]
```

## Campaign state

Per zone: owner, drawn garrison (ticket 02) and its losses, capture in progress; per side: stocks (ticket 06); destroyed scenery (ticket 07); mission counter; a **format version**.
The file format (YAML or Lua through `luadata`) is chosen while writing ticket 05, so that the state file and the campaign state stay one structure.

## Validation

Unknown airfield or point, duplicate zone, connection to an unknown zone, a graph that is not connected, an objective naming an unknown zone, a garrison alias unknown, a size class whose parameters are out of range, a state whose version or zone list does not match `campaign.yaml` (a zone renamed or removed is reported, never silently dropped).
Each message in both locales.

## Done when

Worker/manager/models split, typed, tested first (TDD); a `veaf-tools campaign init <folder>` that creates the initial state from `campaign.yaml`, and `veaf-tools campaign validate`; `pyproject` ratchets respected.
