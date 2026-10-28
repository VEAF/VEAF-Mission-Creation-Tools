# FEAT-OBJECTIVE-MISSION-V2 — what "Marteau du Golan" did by hand, in the tools

Status: 🔄 in progress

"Marteau du Golan" (Syria, VMCT 6.33.0, flown 2026-10-29) was designed with the AI and the tools, then finished by hand: the briefing's prose validated before any layout, a separate sheet for the Mission Maker, a combat-area map, kneeboard maps turned attack axis up, recon photos, a poster, a calendar banner and a Discord post.
David found the hand-made briefing far better than the tool's, and asked for what was done by hand to become part of the process (2026-10-28, after FEAT-OBJECTIVE-BRIEFING-QUALITY, #1206).
The prototypes are in `VEAF_Syria_MarteauDuGolan/docs/build/`; their logic is taken over, not their code.

What needs DCS running — taking the recon photos, checking the mission in game — is the other lot, run in parallel (`vmct-recon-ingame`).
This lot fixes the interface it delivers to: a folder of JPEG photos and their JSON sidecars (ticket 04).

| # | What | Ticket |
|---|---|---|
| A | The objective-mission prompt: prose validated first, no scripted event told as certain, Mission Maker matters out of the pilots' briefing and into a sheet of their own, ways out (AI CAP, secondary objectives and SAMs outside the operation, an operation that ends with few pilots), code words and "who talks to whom", every zoom checked for units in buildings | 01 |
| B1 | A second map, "combat area", beside the overview | 02 |
| B2 | Kneeboard: portrait maps turned attack axis up, a coordination page (code words), target pages | 03 |
| B3 | Recon photos per objective, in the deck and the kneeboard | 04 |
| D1 | `create_cap_mission` takes a display name; an empty one falls back to the mission name | 05 |
| D2 | `validate_mission` warns on an unknown key (`friendly_name` in `cap_missions`) | 06 |
| D3 | The authoring guide and the prompt say an operation's zone cannot be deactivated on its own | 07 |
| D4 | Known limitation: an "On Road" route with no path leaves the column still, silently | 08 |
| D5 | `build --profile` writes a `.miz` of its own per profile | 09 |
| D6 | `describe_module CTLD` knows the community modules | 10 |
| D7 | No dynamic-slot templates for a side with no slot base | 11 |
| F | A 16:9 poster, a 5.55:1 calendar banner and a Discord post under 2 000 characters, from the built mission | 12 |

Decided with the brief (2026-10-28): existing parameters keep their meaning; everything new is optional; human texts with their accents; each action's documentation and the `.md` pages concerned follow in the same lot; a test for each point.

One branch, one PR.
