# 06 — Documentation and an example campaign

Status: ⬜ ready

- `doc/mission-maker/CAMPAIGN.md` + `CAMPAIGN.en.md`: what a campaign is for a player, how to declare
  one, the size classes, persistence and reset, the performance settings; in `mkdocs.yml` nav with its
  translation; `poetry run docs-check` clean; support bot index refreshed
  (`services/support-bot/scripts/refresh_doc_pages.py`).
- `MISSION_YAML_REFERENCE` (FR/EN): the `CAMPAIGN` module.
- A Lua module page for `veafCampaign`.
- An example mission folder: a small Caucasus campaign (~12 zones), built in CI like the other examples.
- `CONTEXT.md`: campaign, campaign zone, size class, dormant zone, sortie.
- `CHANGELOG.md` entry; `ROADMAP.md` §4 rows `DYNAMIC-CAMPAIGN` / `PERSISTENCE` updated.
