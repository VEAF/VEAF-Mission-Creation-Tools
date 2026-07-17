# 01 — Drop the `Sim` dependency in `veaf.Logger:print`

Status: 🔄 in-progress

## Context

`veaf.Logger:print` (`src/scripts/veaf/veaf.lua`) forwards log lines to the
DCSServerBot channel using `Sim.getMissionName()`. `Sim` does not exist in the
mission scripting environment, so the call raises `attempt to index global 'Sim'`,
crashing every `:error()` on servers wired to DCSServerBot.

## Change

- Replace `Sim.getMissionName()` with `veaf.config.MISSION_NAME or "unknown"`.
- Keep the DCSServerBot forwarding behaviour otherwise unchanged.

## Tests (TDD)

In `test/lua/test_veaf.lua` (or the logger's test file):

- with `dcsbot` mocked and `veaf.config.DCS_SERVER_BOT_CHANNEL` set, calling
  `:error("x")` must **not** raise, and must forward a message containing
  `veaf.config.MISSION_NAME`;
- with `veaf.config.MISSION_NAME` nil, the forwarded message uses `"unknown"` and
  still does not raise.

## Done when

- `Sim` no longer referenced in `veaf.lua`.
- New tests green; `poetry run test-lua` passes.
- luacheck + stylua clean.
