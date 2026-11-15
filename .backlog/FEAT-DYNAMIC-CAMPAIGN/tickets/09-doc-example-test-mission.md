# 09 — Documentation, example campaign, test mission, in-game check

Status: 🧑 waiting-human — code and tests done on `feature/dynamic-campaign-v1` (2026-11-15); the in-game check of the test mission is David's

- `doc/mission-maker/CAMPAIGN.md` / `.en.md`: a "Persistent mode" part — what a player sees, how to declare it, every `dynamic`, `air`, `economy`, `tasks`, `intel` key with its default, the save file, reset, what is not restored after a restart (aircraft and convoys in flight).
- `doc/mission-maker/scripts/` page of `veafCampaign` updated; support bot index refreshed if a page is added or retitled.
- `src/defaults/campaign-folder-persistent/`: a small Caucasus persistent campaign (6 to 8 zones around Kobuleti, Senaki, Kutaisi), built in CI by the existing example test.
- A test mission folder for David, with a `Campaign → Self-check` admin command that prints one verdict line per mechanism (zones placed, save written and reloaded, dormancy, sorties, credits), so the check needs no log.
- `CHANGELOG.md` entry; `CONTEXT.md` terms (persistent campaign, dormant zone, sortie, task, reveal).
- A demo mission step (`VEAF/VEAF-Demo-Mission-v6`) if a persistent campaign fits in the demo; otherwise say why in the PR.
- `known-limitations.yaml` gets what the in-game check measures.

## Done when

`docs-check` clean, the example builds in CI, David has the test mission and the step-by-step check.

## As built

The documentation is a page of its own, `doc/mission-maker/PERSISTENT_CAMPAIGN.md` / `.en.md`, linked from the `veafCampaign` module page, rather than a part of `CAMPAIGN.md`: the two modes are read by different people.
The test mission is `D:\dev\_VEAF\tmp\dynamic-campaign-test` on David's workstation.
No demo mission step: a persistent campaign is a whole mission of its own, not a step of the demo's tour, and the lot is merged into the integration branch `feature/dynamic-campaign`, not into `develop` where the demo follows the tools.
