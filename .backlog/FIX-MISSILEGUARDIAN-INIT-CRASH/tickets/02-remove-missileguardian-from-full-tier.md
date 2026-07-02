# 02 — Stop auto-enabling MISSILEGUARDIAN (remove from `full` tier)

**Status:** ✅ done

Root-cause context: the crash (ticket 01) only bit because `MISSILEGUARDIAN` was
auto-enabled. It is a 2021 WIP training-tools relic (first commit 2021-04-10,
never past `0.0.2`) that David does not use, yet it sat in the `full` tier — so
`prepare --tier full` / `convert-v5` set `MISSILEGUARDIAN: true` by default. That
is how it reached Tripack's mission.

Change: `mission_template.py` — `MISSILEGUARDIAN` now has `tiers=frozenset()`
(no named tier). It remains in `SELECTABLE_MODULES`, so the `custom` picker still
offers it (tagged `opt-in`, via `module_lowest_tier(...) or "opt-in"` in
`prepare.py`). Non-enabled FEATURE modules are simply omitted from the generated
`modules:` block, so `full` no longer emits it.

Tests: `test_missileguardian_is_opt_in_only` (not in `full`, absent from the full
`modules:` block, still selectable, emitted when explicitly requested);
`module_lowest_tier("MISSILEGUARDIAN")` now returns `None`.

Docs: `doc/` lists the module (Protection / Specialized) but never ties modules to
tiers — no doc change needed. Shipped default `mission.yaml` already had it
commented-out — unchanged (lockstep OK).
