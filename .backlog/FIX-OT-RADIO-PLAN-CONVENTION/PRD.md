# FIX-OT-RADIO-PLAN-CONVENTION — Open Training radio plans: VHF for the airfields, UHF for the assets and the flights

Status: 🧑 waiting-human

David, 2026-11-11, flying an A-10C on the Syria OT: no VHF channel for Ramat David, no UHF channel for Archer, while the UHF radio carried airfields. "We had said VHF is the airfields, UHF the assets — Magic, the AWACS, the tankers — and the channels left are the flights, Archer, Bengal."

## The defect

The shipped template (`src/defaults/mission-folder/src/presets.yaml`) follows that convention: `primary_1` (resolved in UHF) = flights, carriers, Magic, tankers; `primary_2` (resolved in VHF) = airfields.
The OT prompt says otherwise (`new-open-training-mission.{fr,en}.md` §4.10): "UHF = bases, AWACS, flights, tankers; VHF = flights".
The eight OTs were written from the prompt, so each one spreads its airfields and its flights over both radios, and with 20 channels per radio each airfield or flight lands in only one of them (Syria: Ramat David UHF only, Archer and Bengal VHF only). Measured 2026-11-11: airfields in both lists in all eight, except Normandy (one radio).
They also keep `Guard` on channel 1 of each radio, which the prompt has ruled out since 2026-10-20.
The injector is not at fault: it puts `primary_1` in the UHF radio and `primary_2` in the VHF radio, as asked.

## Decisions — 2026-11-11

| # | Question | Decision |
|---|---|---|
| D1 | The convention | **VHF (`primary_2`) = airfields** (their DCS tower frequencies, `bases` collection) and FARPs. **UHF (`primary_1`) = assets, then flights**: AWACS and tankers first (S-3B carrier tankers included), then carriers, then the flights (Archer, Bengal…) in the channels left. No `Guard` (rule of 2026-10-20) |
| D2 | What is left out of UHF | **No drones or exotic assets** (Darkstar and the like), David's words. When AWACS + tankers + carriers + flights exceed 20, flights are dropped from the end of the list; each OT reports what it left out |
| D3 | VHF overflow | More than 20 airfields (Sinai has 22): keep the ones with player slots and the ones near the combat zones; report what was left out |
| D4 | Red | Same convention for the red plan where red flies |
| D5 | Normandy | One radio (warbirds): left as it is, said in the outcome |
| D6 | Where | VMCT: the prompt (fr, en) and anything else in VMCT that states the old convention (grep the prompts, the authoring guide, the doc). The eight OTs: their `presets.yaml`, outside this repository — each diff shown to David before its rebuild; no commit, no deploy without his go |

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [The OT prompt states the convention](tickets/01-prompt.md) | ✅ |
| 02 | [The eight OTs follow it](tickets/02-ots.md) | 🧑 |
