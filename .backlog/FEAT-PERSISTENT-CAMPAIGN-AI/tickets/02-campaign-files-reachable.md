# 02 — Campaign files reachable by `read_mission_file` / `edit_mission_file`

Status: ✅ done
Type: feature

## What

- A folder holding `campaign.yaml` and no `mission.yaml` is a campaign folder: `campaign.yaml` and `briefing.yaml` are reachable there, nothing else.
- `edit_mission_file` with an empty `search` creates a reachable file that does not exist yet (its content must read as YAML); an empty `search` on an existing file stays refused.
- The two actions' descriptions say so.

## Done when

- Tests: read and edit `campaign.yaml`, create `briefing.yaml`, refuse `campaign-state.yaml` and any other name, refuse a create over an existing file.
