# FIX-OT-RADIO-PLAN-CONVENTION — Open Training radio plans: VHF for the airfields, UHF for the assets and the flights

Status: ✅ done

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
| 02 | [The eight OTs follow it](tickets/02-ots.md) | ✅ |

## Outcome — 2026-11-11

- Prompt fixed in #1265 (OT §4.10 fr/en, objective-mission prompt, authoring guide); the prompt also tolerates the arena AWACS left off the UHF radio in the build's "no preset" list.
- Seven OTs rewritten (`channel_lists`, README radio table, and the `gen_12_*` generator where the OT has one, checked equal to `presets.yaml`), rebuilt, checked on a blue A-10C II: airfields on one radio, assets and flights on the other, no Guard. No weather variants: every OT has `pipeline.weather: false` (David, 2026-10-12).
- Left out: Guard everywhere; Darkstar-1, Focus-1, AWACS-Arene-Rouge (arena AWACS); Reaper-1/2 (Caucasus drones); Gordon on the UHF (Marianas, Syria, 21st channel).
- Left as they are, David's choice: the CH-47's explicit `radio_uhf_30` list (Guard on channel 1) in Caucasus, GermanyCW and Syria; Normandy (D5).
- Deployed with `Publish-OT.ps1`: Caucasus, GermanyCW, Syria, Marianas, Sinai, PersianGulf. Falklands is committed and built but served by no instance in `calendrier.yaml`.
