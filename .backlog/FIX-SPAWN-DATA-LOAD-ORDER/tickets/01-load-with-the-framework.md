# 01 — The spawn data loads with the framework, and a campaign mission draws its garrisons with their air defence

Status: ⬜ ready

- `spawn_data_injector_worker.inject_spawn_data`: the load as last action of both framework triggers (dict or list `actions`, and the `trig.actions` string), once; the trailing trigger and a warning only without them.
- Tests in `test/python/spawn_data_injector/test_spawn_data_injector.py`: both framework triggers end with the load, no trigger of its own, the mission-script trigger untouched, a list of actions extended, injected twice it loads once; the existing tests (missions without framework triggers) keep the trailing trigger.
- One source for the two trigger comments, used by the builder and the injector.
- **Proof on a built mission**: build a campaign mission (Kolkhida mission 1, `D:\dev\_VEAF\_campaigns\campaign-kolkhida\missions\mission-01\mission`, with an executable built from the branch and `veaf-build publish-local`), then run its `l10n/DEFAULT` scripts **in trigger order** under Lua 5.1 with `test/lua/dcs_mocks.lua` and check that `veafCampaign` draws Senaki's garrison with a long-range SAM and no `cannot find group` error — the failure first reproduced on today's order, then gone.
- `CHANGELOG.md` under `[Unreleased]` / Fixed.
