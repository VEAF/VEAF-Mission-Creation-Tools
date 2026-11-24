# Prompt — build a VEAF persistent campaign

> Served by the `describe_mission_prompt` action (`kind: persistent-campaign`) when a user asks for a persistent campaign.
> The campaign is built in a **folder of its own**: ask the user where to create it (for example `Documents\VEAF\Campaigns\<name>`).

---

You are going to build a VEAF **persistent campaign** for DCS World **from scratch**, with the VEAF Mission Creation Tools v6 and the `veaf-mission-mcp` MCP server.

A persistent campaign is **one single mission** that runs on a server for weeks, in the spirit of Foothold: zones that change hands, a front that moves on its own, enemy air, credits to spend, and a save that resumes where the server stopped.
Everything starts from a `campaign.yaml` file (`mode: persistent`) and a template mission, `template/`.
The user may have neither a terminal nor the repository: everything is done through the MCP actions.

## 0. First of all

1. **Read the VEAF authoring guide** (`describe_authoring_guide`) and follow it, in particular its **"A campaign mission"** and **"A persistent campaign"** paragraphs: they are the rules learnt on the first persistent campaign (*Bouclier de l'Oronte*, Syria). This prompt does not copy them: it says **when** to apply them.
2. Call `capabilities` and read the **known limitations** (`describe_known_limitations`, the short list, then in full only the entries the campaign meets).
3. **What is missing or broken in the tools, you report** in a **"Feedback for VMCT"** block of your final report (what, where, how you saw it, what you did instead).
4. Answer in English, concisely. Ask your questions **one at a time**, with choices and your recommendation.
   The mission takes the user's language (`mission.language: en` in the template's `mission.yaml`).

## 1. The questions to ask (and only those)

One at a time:

1. **The theatre and the era** (modern, Cold War with a year, WW2). The era decides the garrisons' equipment.
2. **The players' side** (`player_side`, blue by default) and **the campaign's name**.
   Also offer a **fixed file name** for the mission (`mission_file`, for example `Campaign_Orontes`): the server browser shows it, and a redeploy just replaces the file.
3. **The front**: where it runs, and how many zones (recommendation: 8 to 14 for a first campaign).
   Offer a map of the zones: each side's airfields (`list_airfields`), outposts between them (towns, crossroads, passes: `geocode`), one or two neutral zones in the middle, and the connections that make the front.
   Show it as a table (name, place, starting side, class `airfield` or `outpost`), and have it approved before writing.
4. **Factories and depots** (`kind: factory` / `kind: depot`): recommendation, a factory far behind the lines and a depot on the road to the front, for each side. They make and carry the resources the AI spends.
5. **Long- and medium-range SAMs**: on which key zones (a large rear base, a factory, a depot), two long-range a side at most, 120 km apart at least.
6. **What the enemy AI does**: by default it counter-attacks and resupplies (`dynamic.attacks: [red]`, `dynamic.supply: [red]`), with the shipped values. Only offer to change the economy (`dynamic.economy`, `dynamic.resources`) when the user asks: the guide says why the shipped values hold.

Everything else you decide with the guide and the shipped example, and you say so.

## 2. Method

- **Nothing from memory.** Airfields → `list_airfields`; places → `geocode` (show the point found); coordinates → `resolve_coordinates`; unit types → `list_unit_types`.
- **A zone on an airfield is declared on the airfield** (`at: { airfield: … }`), never at coordinates beside it.
- **The campaign's files are written with `read_mission_file` and `edit_mission_file`**, with the **campaign folder** as `mission_path`: they reach `campaign.yaml` and `briefing.yaml` there.
  `edit_mission_file` replaces an exact passage: read first, then replace block by block (the `campaign:` block, the `zones:` list, the `connections:` list). An **empty** `search` creates a file that does not exist yet (`briefing.yaml`).
- **`campaign_validate` after every change** to `campaign.yaml` or the template. A warning is a defect the first evening on the server would show: fix it, do not just quote it.

## 3. Order of work

1. **The example**: `campaign_init` with `example: persistent` on the chosen folder. It copies the shipped example there (the Georgian front, 11 zones) without starting the campaign yet.
2. **`campaign.yaml`**: read it in full (`read_mission_file`); its comments explain every key. Rewrite it for the campaign approved in 1:
   - the `campaign:` block (`name`, `theatre`, `era`, `mode: persistent`, `player_side`, `mission_file`);
   - `zones:` and `connections:`;
   - in `dynamic:`, keep the shipped values; adapt `support.assets` and `economy.tanker` to the names of the groups you will place in the template (step 3).
   Then `campaign_validate`, until it is clean. It checks the template (AWACS, tankers, radio plan) only once the template is there: its silence at this point says nothing about the template.
3. **The template**: `scaffold_mission` into `<campaign folder>\template`, with the campaign's `theatre` (template `standard`).
   Then apply the guide, paragraphs "A campaign mission" and "A persistent campaign": an AWACS and two tankers (a boom, a basket) orbiting over your own rear, their channels in `src/presets.yaml`, `modules.ASSETS`, the exact names repeated in `dynamic.support.assets` and `dynamic.economy.tanker`.
   **No `#veafInterpreter` unit** in the template: what the campaign must hold is declared as a zone.
4. **`campaign_validate` until zero errors and zero warnings.**
5. **`briefing.yaml`**: create it (`edit_mission_file`, empty `search`) with `operation`, `subtitle`, `situation` and the **axes of effort** under `axes:` (a `title` and a `text` each), in the pilots' language. A text holding ": " is quoted. Then `campaign_validate`.
6. **Start**: `campaign_init` **without** `example`. It writes `campaign-state.yaml`.
   Change the zones **before** this step: afterwards, a zone added or renamed is a `campaign_validate` error. For a persistent campaign the way out loses nothing: the user deletes `campaign-state.yaml` in the File Explorer, and you run `campaign_init` again.
7. **The mission**: `campaign_next`. It lays down `missions\mission-01\mission`, the players' waypoints, the radio plan, the DCS briefing, the theatre dossier and the kneeboard pages. Read every warning it returns and fix it in the template or `campaign.yaml`, then run `campaign_next` again: it refreshes without overwriting the work done.
8. **Build**: `validate_mission` then `build_mission` on `missions\mission-01\mission`, then `inspect_built_mission`. The guide, section "Finish", says what to read in the result.

## 4. What you hand the user

- The built `.miz` (`<mission_file>.miz` in `missions\mission-01\mission`): that is what goes on the server, in its `Missions` folder.
- The **theatre dossier** (PPTX and PDF) and the **kneeboard pages**, next to the mission folder: to share with the pilots.
- What the server must have, in plain words:
  - `io` and `lfs` open in its `MissionScripting.lua`, otherwise the campaign runs but does not save (they are on the VEAF servers);
  - the save is written to `Saved Games\DCS\Missions\Saves\<campaign name>\persistent.state`;
  - the weather and the time come from the server (MizEdit, RealWeather): the mission fixes none;
  - a reset is done in game: F10 → Other → VEAF → Campaign → Reset the campaign (admin).
- For an **update** later: change `campaign.yaml` or the template, `campaign_validate`, `campaign_next`, rebuild, redeploy the same file. A campaign already running keeps what its save drew (the guide says what to tell about it).
- The **"Feedback for VMCT"** block.

## 5. Check before saying "it's ready"

- `campaign_validate`: zero errors, zero warnings.
- The build succeeded, and `inspect_built_mission` shows the AWACS and the tankers with their tasks and frequencies.
- Say what you checked, and what can only be checked in game, on the server.
