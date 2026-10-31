# 05 — `mission-check` judges the briefing's wind against the model

Status: ⬜ ready

`veaf-tools dcs mission-check` gains a `wind` check (PRD D6, D7), which needs no DCS:

- a. **Where**: each player departure (airbase or FARP of a `Client` / dynamic slot), each combat zone of an objective, and each waypoint of a helicopter flight's route; read from the `.miz` and the mission's VEAF configuration, de-duplicated within 5 km.
  At each, the simulated wind by the layers of PRD D5 and the strongest wind from 0 to 600 m above the ground (ticket 01 b).
- b. **What the texts announce**: every wind mention in the briefing texts — the `.miz`'s `descriptionText`, `descriptionBlueTask` and `descriptionRedTask`, and, when the mission folder has them, the approved content `docs/briefing-contenu.md` and the deck's text (`docs/briefing.pptx`, through `python-pptx`) — in both languages the prompts write (`270/17`, `270° 17 kt`, `17 kt from the west`, `vent du 270 pour 17 nœuds`, "stronger aloft"…).
  Each mention is compared with the simulated range at the layer it names, within the tolerance of PRD D7; a contradiction is a **failure** naming the text, the sentence and the simulated range.
  A mention without a figure is listed; a briefing that mentions no wind, when the helicopter rule of c is breached, fails too — the pilots had no warning.
  The kneeboard pages are images drawn from the same words and the same `.miz` by `build_mission_briefing`: checking the deck covers them, and the check says so rather than read images.
- c. **What helicopters fly into**: with at least one helicopter slot, the rule of PRD D6 produces a **warning** line naming the place, the height and the speed.
  The report gains that level (`Line` in `veaf_libs/dcs_mission_check.py` has `ok` = `True`, `False` or `None`): the verdict counts warnings apart, and the exit code stays 0 unless a failure exists.
- d. **Optional measurement** (`--measure-wind`), with the test copy running in DCS: `atmosphere.getWind` at the same points and heights through the bridge `mission-check` already embeds (REFACTOR-BRIDGE-ONLY), compared with the model; a gap over 0.5 kt anywhere fails with the DCS version read from the game and the model's (`MODEL_DCS_VERSION`, ticket 01 e): DCS has changed its wind, the whitepaper's measurement has to be redone.
  The measured table is written as `<stem>_CHECK.wind.json` beside the test copy.
- e. The thresholds, the tolerance and the layers are ticket 04 e's constants.
- f. Where the wind check runs without DCS, it runs **before** the in-game checks, so `mission-check` without a running DCS still gives the wind verdict and says the rest needs the game.

Done when:

- the extraction of wind mentions is unit-tested on real sentences: the original *Marteau du Golan* briefing ("17 kt au sol, plus fort en altitude") **fails** against its setting (24 kt at the surface, 36 at 1,000 ft); its rewritten briefing passes;
- the warning level shows in the verdict without changing the exit code;
- the Lua chunk of `--measure-wind` and the parser of its answer are unit-tested without DCS (a vector blowing east reads "from 270"), and a run on the survey mission with the whitepaper's reference setting finds no gap;
- the `mission-check` documentation pages (FR and EN) describe the wind check, its places and layers, the thresholds, what fails and what warns, and `--measure-wind`.
