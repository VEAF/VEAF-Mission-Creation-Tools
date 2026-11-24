# FEAT-PERSISTENT-CAMPAIGN-AI — build a persistent campaign with the AI assistant alone

Status: 🔄 in-progress

VMCT 6.39.0 shipped the persistent campaign (`mode: persistent`, page `doc/mission-maker/PERSISTENT_CAMPAIGN.md`).
The first one, *Bouclier de l'Oronte* (Syria), was built by Claude Code sessions holding the whole repository.
A mission maker has the installed `veaf-tools.exe` and Claude Desktop with the VEAF MCP server: no repository, often no terminal.
David noticed on 2026-11-24 that the docs say nothing about building one with an AI, and chose to close the gap fully, in one PR.

## What was missing (measured 2026-11-24)

- The MCP catalogue covers the multi-mission loop only (`campaign_status`, `campaign_apply`, `campaign_next`, `campaign_briefing`).
  `campaign init` and `campaign validate` are CLI commands only: an AI on the MCP alone can neither start nor check a campaign.
- The shipped example (`published/src/defaults/campaign-folder-persistent/`) is reachable from no action.
- `read_mission_file` / `edit_mission_file` reach `mission.yaml` and `src/*.yaml` of a **mission** folder only: `campaign.yaml` and `briefing.yaml` of a campaign folder are out of reach, and so the AI could not write the campaign at all.
  Nor can either action create a file that is not there yet (`briefing.yaml`).
- The MCP ships start prompts for an Open Training and an objective mission, none for a persistent campaign.
- `PERSISTENT_CAMPAIGN.md` never mentions the assistant; the AI catalogue has no persistent-campaign section.

## Decisions

- **`campaign_init` lays down the example, then starts the campaign: two calls, one action.**
  With `example` (`persistent` or `multi-mission`) on a folder with no `campaign.yaml`, it copies the shipped example's files and stops: the state is not drawn yet, since the AI is about to rewrite every zone for the user's theatre.
  Without `example`, it is `campaign init`: the state drawn from `campaign.yaml`.
  An `example` on a folder that already has a `campaign.yaml` is refused: the tools never overwrite it.
  The copy lives in `CampaignWorker.scaffold`, so a CLI option could call it later; none is added, the doc keeps telling a mission maker at the terminal to copy the folder.
- **`campaign_validate` returns `{errors, warnings}`**, two lists of messages, and never raises on an invalid campaign: its job is to report.
- **`read_mission_file` / `edit_mission_file` also take a campaign folder** (one holding `campaign.yaml` and no `mission.yaml`), where `campaign.yaml` and `briefing.yaml` are reachable, and nothing else.
  An edit with an **empty `search`** on a file that does not exist yet creates it; on an existing file it is refused as before.
- **The prompt is `new-persistent-campaign.{fr,en}.md`**, served by `describe_mission_prompt` under the kind `persistent-campaign`.
  It holds the questions and the order of work, and points to the authoring guide's persistent-campaign rules rather than copying them.
  The authoring guide lists the third kind next to the two others.

## Scope

| # | Ticket |
|---|---|
| 01 | [`campaign_init` and `campaign_validate` MCP actions](tickets/01-init-and-validate-actions.md) |
| 02 | [Campaign files reachable by `read_mission_file` / `edit_mission_file`](tickets/02-campaign-files-reachable.md) |
| 03 | [The `persistent-campaign` mission prompt](tickets/03-persistent-campaign-prompt.md) |
| 04 | [Docs: "With an AI" and the catalogue](tickets/04-docs.md) |

## Out of scope

- Uploading the mission to a server: the prompt says what to upload and where it saves, the server side stays the mission maker's (or the server admin's).
- A CLI `--example` option for `campaign init`.
