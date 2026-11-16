# POC-AUTO-TOWER — an automatic tower that frames the human pilots in the control zones

Status: ⏸ paused — opened 2026-11-16, paused the same day (David): the idea is noted, not for now.

## Origin

On 2026-11-16 a pilot suggested the LivingRadio mod for our servers (DCS user files 3351787, read in its version 0.5.0a6).
The review did not keep it, and the reasons shape this idea:

| LivingRadio, as read in its code | Why it does not fit our servers |
|---|---|
| English and Russian only; "French" is an accent on English | our servers talk French |
| The towers talk on every DCS frequency of the airfield at once, VHF included | our pilots talk on the airfield VHF; the bot would talk over them |
| Nothing knows when a human is transmitting on SRS | same: it talks over the humans |
| A calm frequency gets chatter after about 3 minutes, plus banter and gags | the frequencies would be busy all the time |
| In server mode every AI group of the map gets a voice, with no budget | heavy on missions with ranges full of targets |
| One Python process per DCS server, one `DCS-SR-ExternalAudio.exe` per transmission, and an SRS server started if none answers | one more moving part per server, and a clash with the SRS servers DCSServerBot runs |

The idea David took from it: our own tower, much narrower, that only frames what the human pilots do near an airfield.

## The idea

- It talks **to the human pilots only**, in French, on the airfield's VHF frequency.
- It takes **no input from the pilots**: no voice recognition, no F10 menu. A pilot may answer on the radio; nobody listens.
- What triggers a call is **where a human is and what he does**: an entry point into the control zone, a leg of the circuit (downwind, base, final), lining up and taking off, landing and vacating, leaving the zone.
- So it is closer to an aerodrome flight information service than to a real tower: information and instructions, never a clearance that answers a request.
- The goal is to frame the humans' movements in the control zones, not to control the AI, which taxis and takes off on its own whatever is said.

## Sketch, if it is ever built

- **Detection**: mission-side Lua injected by a server hook, without touching the `.miz` files. It samples the human units every second (64 at most, cheap) and listens to the DCS events (engine start, takeoff, runway touch, landing).
- **Geometry**: DCS gives the runways; the runway in use comes from the wind at the airfield; the circuit legs are computed from it. The entry points are not in DCS: one data file per airfield.
- **Back channel**: the hook reads the mission state and sends it over local UDP to the external program; no `dcs.log` tailing, no desanitizing.
- **Voice**: a local French text-to-speech (Piper has French voices), then SRS through `DCS-SR-ExternalAudio.exe`. A tower says a few things per pilot and per circuit, so one launch per call is acceptable for a proof of concept. The program must run on the machine of the SRS server (ExternalAudio talks to 127.0.0.1 only).
- **On the air**: one queue per airfield, one call at a time, and the order of arrival gives the numbers in the circuit ("number 2, follow the Viper on final").

## Open questions, with a recommendation each

| # | Question | Recommendation |
|---|---|---|
| a | Which phraseology? | Start from what our pilots already say (kneeboard, VEAF phraseology if written down), not from an invented one. |
| b | Which callsign for the pilot: the unit's DCS callsign or the player's nickname? | The unit's callsign; nicknames are often unpronounceable. Depends on what our pilots announce. |
| c | Scope of the proof of concept? | One airfield (Tbilisi on the Caucasus Open Training), from lining up to vacating, no taxi at first. |
| d | A human controller on the airfield? | A switch per airfield to silence the automatic tower; detecting the human later. |
| e | Where does the code live? | To decide when the lot resumes: a new repository or an existing VEAF one. |

## Known limit

It will still talk over a pilot who is transmitting, since nothing tells it a human is on the frequency.
Short calls at the moments the pilot expects them reduce it; solving it means listening to the SRS frequency, a later step.

## Out of scope

- MOOSE `FLIGHTCONTROL`: not considered (David's choice, 2026-11-16).
- LivingRadio itself: reviewed and not adopted (above).
- DCS-ATC (Iceman1991): not reviewed; may be read for ideas when the lot resumes.

## Definition of Done (of the proof of concept)

- On one airfield of one Open Training, a human flying a circuit hears the French calls on the VHF at each step, in the right order.
- Two humans in the circuit get their numbers.
- The load on the server (Lua and the external program) is measured.
