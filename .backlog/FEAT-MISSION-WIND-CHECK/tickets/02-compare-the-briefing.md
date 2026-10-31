# 02 — the briefing's wind against the measurement, and the wind helicopters cannot fly

Status: ⬜ ready

On the measurement of ticket 01, `mission-check` judges:

- a. **What the texts announce.** Every wind mention found in the briefing texts — the `.miz`'s `descriptionText`, `descriptionBlueTask` and `descriptionRedTask`, and, when the mission folder has them, the approved content `docs/briefing-contenu.md` and the deck's text (`docs/briefing.pptx`, through `python-pptx`; the words passed to `build_mission_briefing` are not kept anywhere else) — read in both languages the prompts write (`270/17`, `270° 17 kt`, `17 kt from the west`, `vent du 270 pour 17 nœuds`, "stronger aloft"…).
  Each mention is compared with the measured range at the layer it names, within the tolerance of PRD D5; a contradiction is a **failure** naming the text, the sentence and the measured range (PRD D3).
  A mention without a figure is listed; a briefing that mentions no wind at all, when the measured low-layer wind exceeds the threshold of b, is a failure too — the pilots had no warning.
  The kneeboard pages are images drawn by `build_mission_briefing` from the same words and the same `.miz`: checking the deck covers them; the check says so rather than reading images.
- b. **What helicopters fly into.** With at least one helicopter slot, the thresholds of PRD D4 (20 kt between 0 and 600 m above a helicopter place, 15 kt of shear from the surface) produce a **warning** line naming the place, the height and the value.
  The report gains that level (`Line.ok` has none today): the verdict line counts warnings apart, and the exit code stays 0 unless a failure exists.
- c. The thresholds and the tolerance are named constants in one module, quoted in the report's lines.

Done when: the extraction of wind mentions is unit-tested on real sentences — the original *Marteau du Golan* briefing ("17 kt au sol, plus fort en altitude") **fails** against its measurement, its rewritten briefing passes — and the warning level shows in the verdict without changing the exit code.
