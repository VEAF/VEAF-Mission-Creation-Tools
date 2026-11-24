# 03 — The `persistent-campaign` mission prompt

Status: ✅ done
Type: feature

## What

- `veaf_mission_mcp/data/mission-prompts/new-persistent-campaign.fr.md` and `.en.md`: what to ask the mission maker (theatre, players' side, zones and their classes, factories and depots, the `dynamic:` essentials), then the order of work — `campaign_init` with the example, `campaign.yaml` rewritten, `template/` scaffolded with its AWACS and two tankers, `campaign_validate` until clean, `campaign_init`, `campaign_next`, `briefing.yaml` axes, build, what to upload to the server.
- It points to the authoring guide's "A persistent campaign" rules, and copies none.
- `describe_mission_prompt` takes the kind `persistent-campaign`; the authoring guide lists it.

## Done when

- A test serves both languages; the prompt names only actions that exist in the catalogue.
