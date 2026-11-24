# 01 — `campaign_init` and `campaign_validate` MCP actions

Status: ✅ done
Type: feature

## What

- `CampaignWorker.scaffold(example)`: copies the shipped example (`campaign-folder-persistent` or `campaign-folder`) into the campaign folder, creating it; refuses an unknown example, a missing shipped example, and a folder that already has a `campaign.yaml`.
- The shipped example is found beside the installed executable (`published/src/defaults/<name>`), else in the checkout (`veaf_libs.shipped_defaults`).
- MCP `campaign_init(campaign_folder, example?)`: with `example`, `scaffold`; without, `init`. Returns what was done and the warnings; raises on an error.
- MCP `campaign_validate(campaign_folder)`: `{valid, errors, warnings}`.

## Done when

- Tests first, for the worker, the resolver and both actions.
- Both actions in `doc/developer/mission-editing-mcp.md` and `doc/mission-maker/AI_ASSISTANT_CATALOG.md` / `.en.md`.
