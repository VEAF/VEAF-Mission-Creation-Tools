# FIX-BUILD-NAME-AND-OT-PLACEMENT — The wizard proposes the mission's own name, and the OT prompt places defenses on their own side and off the trees

Status: ✅ done

Three Discord reports, read on 2026-11-12, agreed by David the same day ("oui, les trois").
This lot is the tool's share; the OT repositories are fixed in a separate session (Beslan, an audit of every OT's combat zones, Akamas).

## The reports

1. **"Wrong name proposed on build"** (Flogas, forum *retours-et-suggestions-outils-veaf*, thread 1561097966645805158, opened 2026-10-17, bumped 2026-11-08, unanswered).
   Clone `VEAF-Open-Training-Mission-Sinai-v6`, fetch the updater, run it, run `veaf-tools.exe`, choose `build`: the wizard proposes `VEAF-IMC-Day` instead of the mission's name.
   `VEAF-IMC-Day` appears nowhere in the Sinai repository nor in VMCT.
   Cause, read in the code: `_resolve_prompt_default` (`veaf_libs/tui.py`) ranks **the last saved preference above the value derived from `mission.yaml`**, and the preferences (`veaf_libs/preferences.py`) are one file in `VEAF_HOME` for every folder. So the name typed for another mission, in another folder, wins over the `mission.name` of the folder being built. The plain `build` command, without the wizard, reads `mission.yaml` correctly (`commands/build.py`).
2. **"Battle of Beslan position des ennemis"** (Rex, forum *retours-tests-opentraining*, thread 1568750059053387807): red spawns too close to blue, "within the zone radius without telling a SAM that should stand far from the front", "check the other missions too".
   Measured on `combatZone_Beslan` (Caucasus OT, radius 8 km, x north, y east): red armor north, blue Abrams south; the red markers are laid in a cross around the centre — `Bes-o2` (SA-8) 2.5 km **south**, about 1 km from the Abrams of `allies-2`; `Bes-a1` (Shilka) 1.5 km south. Nothing in `new-open-training-mission` §4.7 says a side's defenses stand on its own side of the line.
3. **"OT Syrie, Akamas dans les arbres"** (Rex, thread 1570181686451507230). The Akamas training family (A1-A3, Syria OT) stands on a wooded peninsula. Its targets are groups placed in the Mission Editor, not markers, so `veafUnits.settleGroup` never moves them; there is no Syria clear-ground catalogue, but `clear-ground check` probes DCS itself on any map. The OT prompt never asks for that check.

## Decisions — 2026-11-12

| # | Question | Decision |
|---|---|---|
| D1 | Which wins for the build's mission name in the wizard | When the folder has a `mission.yaml` with a `mission.name`, **that value wins over the saved preference**. The saved preference still fills the prompt where no `mission.yaml` gives a value. Same treatment for any other prompt whose `mission.yaml`-derived value is specific to the folder (read `yaml_defaults` and decide per key; say which in the PR) |
| D2 | The mission folder prompt | Check whether a saved folder from another run can be proposed in place of the current one (same global preference file). If so, fix it the same way: the current folder wins when it holds a `mission.yaml`. If not, say so in the Outcome |
| D3 | Placement rule, OT prompt | `new-open-training-mission.{fr,en}.md` §4.7 (and §4.6 where it applies): **each side's defenses stand on its own side of the front line, the medium-range SAMs in depth** (behind its own armor, never between or beyond the opposing units); markers are not laid in a geometric pattern around the zone centre. Give the Beslan measurement as the reason, in the prompt's usual "Measured on …" form. Check whether `new-objective-mission.{fr,en}.md` and the authoring guide need the same sentence, and add it if they place zones with both sides |
| D4 | Trees, OT prompt | §4.6 and §4.7: every vehicle placed in the Mission Editor (inert targets, ships excepted) is checked with `clear-ground check` before the mission is delivered, and moved when it fails; markers are exempt (settled at runtime). Say it needs DCS running, and give the Akamas report as the reason |
| D5 | Out of scope | The OT repositories themselves (separate session); a Syria clear-ground catalogue (FEAT-CLEAR-GROUND-COVERAGE); an automated "marker on the wrong side" check in VMCT — only if the OT audit shows the prompt rule is not enough |

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [The wizard proposes the folder's own mission name](tickets/01-wizard-mission-name.md) | ✅ |
| 02 | [OT prompt: defenses on their own side, vehicles off the trees](tickets/02-ot-prompt-placement.md) | ✅ |

Python (TDD) and prompt text. One branch, one PR.

## Outcome — 2026-11-12

- **D1** — `_resolve_prompt_default` ranks the `mission.yaml` value above the saved preference, which still fills every prompt the `mission.yaml` gives nothing for. `_mission_yaml_defaults` yields only folder-specific keys — `mission_name_or_file` and `input_mission_name_or_file` (from `mission.name`) and `mission_folder` — so all of them take the new precedence; nothing else is read from `mission.yaml`. The test reproducing Flogas's report (`VEAF-IMC-Day` saved, the Sinai name in `mission.yaml`) failed before the fix.
- **D2** — the defect was there: the saved preferences are one file, so a `mission_folder` typed for another mission (an absolute path) was proposed inside a freshly cloned mission folder. A folder holding a `mission.yaml` now proposes `.`, even when that file has no `mission.name` or cannot be parsed. Outside a mission folder the saved folder is still proposed.
- **D3** — `new-open-training-mission.{fr,en}.md` §4.7 states that each side defends from its own side of the front, medium-range SAMs in depth, no geometric pattern around the centre, with the Beslan measurement as the reason; §8 checks the side of every defense. §4.6 is left as it is for D3: its training zones hold only the side to destroy. The authoring guide gets the rule next to its coalition rule, since it is the reference for any zone holding both sides. `new-objective-mission.{fr,en}.md` is left as it is: its zones are red objectives, and it reads the authoring guide.
- **D4** — §4.6 requires `veaf-tools dcs clear-ground-check` on every Mission Editor vehicle (ships excepted, markers exempt), needing DCS, with the Akamas report as the reason; §4.7 points to it and §8 lists it. `new-objective-mission.{fr,en}.md` already asks for the same check; unchanged.
- The mission maker guide (fr, en) says what the wizard proposes in a mission folder; it stated no precedence before.
