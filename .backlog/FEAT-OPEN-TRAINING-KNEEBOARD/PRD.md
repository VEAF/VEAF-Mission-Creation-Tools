# FEAT-OPEN-TRAINING-KNEEBOARD — An Open Training's briefing, as kneeboard pages in the mission

Status: 🔄 in-progress

David, 2026-11-10: the briefing tool built for objective missions could give the Open Trainings an in-mission briefing — short, for the cockpit: what the mission is, the commands that matter, how to behave on the server, and one sheet per combat zone with its position and, when there are some, its recon photos.

## The need

Each OT already has its full briefing in its GitHub `README.md` (bases, support, zones, radio plan, commands).
This lot must **not** duplicate it: no deck, no PDF, no DCS briefing pictures — the OTs already carry their own, drawn by their `tools/gen_map.py`.
What is missing is the cockpit version: **kneeboard pages inside the `.miz`**, condensed from that README.
The three OTs have no kneeboard today (checked 2026-11-10).

## Approach — decided 2026-11-10

David asked whether the OT prompt could not simply drive the existing tool with content written in the Claude session: yes, with two small changes to the tool.
The content is written by the session that builds the OT; the tool only lays it out.

| # | Question | Decision |
|---|---|---|
| D1 | What the tool writes for an OT | **The kneeboard only**: a `build_mission_briefing` option that skips the deck, the PDF and the DCS briefing pictures. Without it the tool would put its maps at the head of the OT's own briefing pictures — a duplicate |
| D2 | Free text in the kneeboard | The kneeboard today shows maps, the flight card, the target list and the code words, no free text. The content gains a list of **sheets** (a title and paragraphs), laid out with the existing `text_pages`, placed **first** in the kneeboard |
| D3 | Order of the kneeboard | Text sheets (mission, conduct, commands) → overview map → per combat zone its zoom and its recon photos → the zone list with coordinates (the existing target list) |
| D4 | One sheet per combat zone | Each combat zone declared in `mission.yaml` is passed as an objective: `zone` = its trigger zone, `title` = its `friendly_name`, `task` = how to start it from the F10 menu. No grouping of the easy / medium / hard levels of one site: the OTs name them differently (`Kobuleti - hélicoptères - facile`, `H1 Hélico Ceyhan – facile`), grouping would mean guessing |
| D5 | Recon photos | Read from the OT's `docs/recon/` when there are some (`veaf-tools dcs recon-photos`); a sheet without photos is still written. Taking them needs DCS on David's machine: his task, after the lot |
| D6 | Mission sheet | Condensed by the session from the OT's README, which stays the source — a summary, not a second document |
| D7 | Conduct sheet | Common to every OT, so written **once** in the OT prompt, not per OT. First draft from David's examples (do not take off from a taxiway, use the airfields' VHF frequencies); David corrects it in the PR |
| D8 | Commands sheet | The list below, fixed with David, written **once** in the OT prompt and copied as is — never recomposed per OT. Aliases first; one raw `_spawn` line |
| D9 | Security | Each command shows its **tier**, never a password; one line explains the tiers and that a pilot off the list adds the tier's password |
| D10 | Rebuilds | The content passed to the tool is saved in the OT's repository, so a rebuild puts the same kneeboard back without rewriting it |

## The commands sheet (D8, D9)

Fixed with David on 2026-11-10. Tiers read from the code the same day (an alias is checked twice: the alias in `veafShortcuts.lua`, then the command it runs in `veafSpawn*.lua` — the stricter wins); **re-read them from the code when writing the sheet**.

| Command | What for | Tier |
|---|---|---|
| `-cas` | a close air support zone: groups scattered around the marker, ended from the F10 menu — **first line** | VEAF pilot |
| `-shilka`, `-manpads`, `-sa6`, `-sa11`, `-sa15`, `-samSR`, `-samLR` | an air defence to suppress or avoid | VEAF pilot |
| `-armor`, `-infantry` | a ground target | VEAF pilot |
| `-convoy, dest <point>` | a moving target | VEAF pilot |
| `-cap <type>` (e.g. `-cap Su-27`) | an air target | VEAF pilot |
| `-tankerlow`, `-tankerhigh` | brings the nearest tanker to FL120 / FL220 | VEAF pilot |
| `-farp <name>`, `-fob` | a forward base | VEAF pilot |
| `-jtac` (laser 1688), `-smoke` (option `color`), `-tacan` | designation, a visual mark, a beacon | open |
| `-point <name>` | name a point (a convoy's destination) | open |
| `-destroy` | remove what is within 100 m of the marker | trusted member |
| `_spawn unit, name <type>, multiplier 4` | one precise DCS type, where `-armor` draws at random | VEAF pilot |

Plus: how to place a marker (F10, right click, *Add marker*, type, validate); the options `side red/blue`, `defense 0-5`, `armor 0-5`, `size`; the F10 menu for what is not a marker (combat zones, *ASSETS*, *CARRIER OPS*).

Left out on purpose: other raw `_spawn`, `-login`/`-logout`, the Mission Master commands, drawings, `-farpNoMarker`, `-zonestart` (hidden alias, trusted-member password; the F10 menu starts the zones), `-send`/`-play`, rare SAMs, ships.

## To judge on the first result (Caucasus OT)

- The overview map is turned along an "attack axis" from the players' departures to the objectives: with 26 zones all over the map and many bases, check it still reads, or keep it north up.
- The zone list with coordinates over 26–27 zones: how many pages.
- The flight card and the code words pages must be absent (no flight plan, no code word).

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [Kneeboard only, and free text sheets](tickets/01-kneeboard-only-and-sheets.md) | ⬜ |
| 02 | [The OT prompt writes the kneeboard](tickets/02-ot-prompt.md) | ⬜ |
| 03 | [Try on the Caucasus OT, doc, CHANGELOG](tickets/03-try-and-doc.md) | ⬜ |

One branch, one PR. Putting the kneeboard into the three OTs comes after a VMCT release, which David decides.
