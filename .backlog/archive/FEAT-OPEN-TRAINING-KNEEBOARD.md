# FEAT-OPEN-TRAINING-KNEEBOARD — An Open Training's briefing, as kneeboard pages in the mission

Status: ✅ done · archived 2026-11-24

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

## What the first result answered (Caucasus OT, 2026-11-10)

Built on a copy of `VEAF-Open-Training-Mission-Caucasus-v6` (the 2026-11-05 build, 26 combat zones, no recon photo), with the prompt's call as written.
The first run gave 51 pages; the fixes below brought it to **36**: three sheets, the overview, the combat area, 26 zone zooms, and a zone list of 5 pages; 21 s with the tiles cached, 6 min on a cold cache.

- **Orientation**: the attack axis means nothing over 26 zones all over the map, so kneeboard-only drops it. North up was tried and turned down: the theatre, wide from east to west, filled a third of the 2:3 page and its labels piled up. Each map now takes the turn that frames it tightest, a north arrow on it.
- **Zone list**: one line per unit took **19 pages**. In kneeboard-only it lists each zone once — its title, the F10 path that starts it, its centre in DDM, MGRS and bullseye — **5 pages**.
- **Flight card and code words**: a flight card *was* there, built from the dynamic-slot templates' routes (tankers, FARPs). Kneeboard-only drops the flight plans, so no flight card and no route on the maps; no code-word page.
- Also fixed: the maps and the pages named a zone `combatZone_Beslan — Bataille de Beslan`; they now use its title. A sheet's lines ran together; each line now stands apart.
- The mission's 9 briefing pictures were left as they were; nothing was written outside `KNEEBOARD/IMAGES/`.

Read again in the code for the commands sheet: `-tankerlow` and `-tankerhigh` run `_move`, declared `SENIOR_PILOT` in `veafMove.lua`, so the sheet says *trusted*. But the alias path calls `veafMove.executeCommand` directly, past the `veafCommands` handler that holds that level: in fact anyone can run them. Left to a lot of its own, written down as the known limitation `tanker-move-aliases-skip-their-security-level`.

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [Kneeboard only, and free text sheets](FEAT-OPEN-TRAINING-KNEEBOARD.md) | ✅ |
| 02 | [The OT prompt writes the kneeboard](FEAT-OPEN-TRAINING-KNEEBOARD.md) | ✅ |
| 03 | [Try on the Caucasus OT, doc, CHANGELOG](FEAT-OPEN-TRAINING-KNEEBOARD.md) | ✅ |

One branch, one PR. Putting the kneeboard into the three OTs comes after a VMCT release, which David decides.

## Tickets, in full

## 01 — Kneeboard only, and free text sheets

Status: ✅ done

### Done when

- `build_mission_briefing` (worker and MCP action) takes an option that writes **only** the kneeboard: no `briefing.pptx`, no `briefing.pdf`, no DCS briefing picture added or replaced; the mission's existing briefing pictures are untouched (test on a built `.miz` holding pictures of its own).
- The briefing content takes a list of sheets — a title and paragraphs — laid out with the existing `text_pages`, first in the kneeboard, in the order given (test).
- Without the option and without sheets, the output is byte-for-byte what it was (existing tests unchanged).
- A mission with no flight plan and no code word gets no flight card and no code-word page (test, if not already covered).
- The MCP action's catalogue entry documents both (CLAUDE.md, MCP action catalogue lockstep).

## 02 — The OT prompt writes the kneeboard

Status: ✅ done

### Done when

- `new-open-training-mission.fr.md` and `.en.md` gain a step, after the build: call `build_mission_briefing` with the kneeboard-only option, the combat zones as objectives (PRD D4) and three sheets — mission (D6), conduct (D7), commands (D8, D9).
- The conduct and commands sheets are written **in the prompt**, in both languages, to be copied as they are; the commands sheet is the PRD's table, tiers re-read from the code, no password anywhere.
- The prompt tells the session to save the content passed to the tool in the OT's repository and to reuse it on a rebuild (D10).
- The conduct sheet is a first draft from David's two examples, flagged for his correction in the PR.

## 03 — Try on the Caucasus OT, doc, CHANGELOG

Status: ✅ done

### Done when

- The kneeboard is produced on a **copy** of `D:\dev\_VEAF\VEAF-Open-Training-Mission-Caucasus-v6` (never the repository itself), and its pages are looked at: the PRD's three points to judge are answered, with the page count.
- A few pages are put in front of David for a look before the PR is called ready.
- The briefing doc says what an OT gets and how; `CHANGELOG.md` has its entry; `docs-check` passes; the support bot index is refreshed if a page was added or retitled.
