# FEAT-CAMPAIGN-BRIEFING-DECK — the campaign's strategic briefing, as a document the squadron reads

Status: 🧑 waiting-human

David, 2026-10-06, testing the start of a campaign: "où est le briefing de campagne (stratégique) ? — je parle d'un document de briefing (comme les ppt que tu génères pour les missions)".
The objective-mission prompt already produces a PPTX briefing after the VEAF template (`.prompts/new-objective-mission.fr.md` §3 and §6); a campaign has nothing of the kind — only `strategic-situation.{fr,en}.txt`, a list of facts, and the DCS briefing text.

A prototype was built by hand the same evening for a three-mission campaign, *Kolkhida*, and reworked on David's feedback until it read like a real military situation brief.
It is kept in [`prototype/`](prototype/): `make_briefing.py` (python-pptx, an OpenStreetMap map, about 400 lines) and the `campaign.yaml` it reads.
This lot turns it into a tool: generated from the campaign folder, regenerated after every mission, written on top of by Claude.

## What David asked of the document

Each point below is a correction he made to the prototype; the lot must hold all of them.

| # | David | What it means |
|---|---|---|
| 1 | "il faut étoffer la situation générale" | a situation brief, not a summary: several pages |
| 2 | "le style doit être plus proche d'un vrai sit-brief militaire, avec la situation stratégique (politique, militaire, économique), les objectifs de la campagne (politiques et militaires, voire économiques), les règles d'engagement, etc." | the structure of an operation order: situation (political, economic, military), mission and intent, objectives by nature, concept of operations by phase, rules of engagement |
| 3 | "et moins de trucs techniques" — quoting "Le cercle est la zone à tenir pour la prendre" and "tant qu'il tourne, chaque véhicule perdu au front est remplacé" | the narrative speaks the language of the staff, never the game's mechanics; the mechanics go to an **annex** at the end |
| 4 | "les forces rouges doivent rester mystérieuses. on a des renseignements qui peuvent être plus ou moins bons mais on ne connait pas le détail des forces" | no enemy count, no enemy reserve figure: qualitative intelligence, each item with the reliability of its source |
| 5 | "sauf pour les trucs fixes comme un SA10" | a fixed site — a long-range SAM — is named, **once it is known** |

Point 5 has a catch the prototype found: a garrison is drawn when the mission **starts**, so before mission 1 nobody knows the long-range SAM's type, not even the tools.
From mission 2 on, the campaign state records every garrison unit by type, and the fixed sites can be named.

## The document

Pages, in the order of the prototype David accepted (VEAF briefing template: 16:9, white, bold title top left, left-aligned text, Calibri):

1. **Cover** — operation name, "Briefing de situation — campagne", theatre, mission count, "situation avant la mission N", contents.
2. **Situation stratégique** — political, economic.
3. **Situation militaire** — enemy forces (intelligence, ticket 02), friendly forces (known: positions, reserves), neutral ground.
4. **Carte stratégique** — zones in their owner's colour at their radius, axes, scale, legend, OpenStreetMap credit.
5. **Mission et intention** — mission statement, purpose, main effect, method, end state.
6. **Objectifs de la campagne** — political, military, economic; conditions of victory, from the campaign's objectives and mission count.
7. **Concept d'opération** — one phase per mission, points of attention.
8. **Règles d'engagement** — targeting, protection of civilians and infrastructure, self-defence.
9. **Mission N** — the tasks of the coming mission.
10. **Annexe — Règles de la campagne** — capture, between missions (logistics, repairs, counter-attack), continuity: generated from the rules, the only page that speaks of mechanics.

**Facts are generated, prose is written.**
The tools generate what the campaign knows: zones and owners, friendly reserves, objectives and victory conditions, the map, the annex, the fixed sites known.
The prose — political and economic situation, intent, objectives by nature, concept, rules of engagement, the mission's tasks — is written by Claude (or the mission maker) into a file of the campaign folder, and kept from one mission to the next; only the parts that change (the mission page, the concept's progress) are rewritten after each debriefing.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-strategic-map.md) | The strategic map, rendered from the campaign | ✅ |
| [02](tickets/02-intelligence-picture.md) | What the players know of the enemy | ✅ |
| [03](tickets/03-briefing-prose-file.md) | The prose, in a file of the campaign folder | ✅ |
| [04](tickets/04-deck-generator.md) | The deck: `campaign briefing`, and `campaign next` | ✅ |
| [05](tickets/05-claude-writes-the-brief.md) | Claude writes the brief, and rewrites it after each mission | 🧑 |
| [06](tickets/06-doc-and-example.md) | Documentation and the example campaign | ✅ |

## What waits for a human

- **The deck as Slides shows it.** No PowerPoint or LibreOffice on the build machine: where a page ends is computed with the font's metrics, the rendering itself was never looked at. Import `briefing-campagne.pptx` into Google Slides and look at every page.
- **Ticket 05 in a real session**: the writing rules are in the `campaign_briefing` action's description; a campaign driven by Claude through the MCP — the prose written at the start, then rewritten after a mission — has not been run.

Measured on the way: python-pptx (with lxml) grows the executable from 40.7 to 45.4 MB, and `campaign briefing` runs from the frozen executable, its template bundled. A French text holding " : " unquoted is read by YAML as a key and its value: `campaign validate` names it.

## Related

- [`FEAT-BRIEFING-MAP`](../FEAT-BRIEFING-MAP/PRD.md) (⏸) renders a mission's map; its ticket 01 and this lot's ticket 01 need the same base layer (tiles, cache, identifying `User-Agent` with no personal data, credit). Build it once, in `veaf_libs`, here; that lot reuses it.
- [`FEAT-MULTI-MISSION-CAMPAIGN`](../FEAT-MULTI-MISSION-CAMPAIGN/PRD.md) (🧑) is the campaign this document describes.
- Found the same evening: when Claude writes the DCS briefing of a campaign mission, it must **add** to the factual block `campaign next` puts there, not replace it — it did replace it on *Kolkhida*. Ticket 05 says so in the instructions it gives Claude.

## Out of scope

- An English deck: the squadron briefs in French; the prose file can carry an `en` text later.
- A PDF: no converter on the build machines; the PPTX imports into Google Slides, which exports PDF.
- Uploading to Google Drive: a publication, left to the mission maker.
