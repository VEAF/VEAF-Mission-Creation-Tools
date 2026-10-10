# 10 — Documentation and an example campaign

Status: 🧑 waiting-human

- `doc/mission-maker/CAMPAIGN.md` + `CAMPAIGN.en.md`: what a campaign is for the squadron, the loop (build, fly, fetch the state file, apply, next), declaring one, size classes, stocks, how to fetch the state file from a server; in `mkdocs.yml` nav with its translation; `poetry run docs-check` clean; support bot index refreshed.
- `MISSION_YAML_REFERENCE` (FR/EN): the `CAMPAIGN` module; `CLI_REFERENCE`: the `campaign` commands.
- A Lua module page for `veafCampaign`.
- An example campaign folder: a small Caucasus campaign (~12 zones, 10 missions), its first mission built in CI like the other examples.
- `CONTEXT.md`: campaign, campaign zone, campaign state, state file, size class, reserve.
- The demo mission step (`VEAF-Demo-Mission-v6`, CLAUDE.md §9 item 9).
- `CHANGELOG.md` entry; `ROADMAP.md` §4 rows `DYNAMIC-CAMPAIGN` / `PERSISTENCE` updated.
