# 03 — The quota follows the user, not the IP

Status: ✅ done

Type: feat

## The problem

The Worker counts requests **per IP**
([`src/index.js:98`](../../../poc/doc-chatbot/worker/src/index.js)): 10 a minute, 100 a day, keyed
on `CF-Connecting-IP`. A bot is one IP for an entire Discord server. Left as is, the whole VEAF
shares a single user's daily allowance and the bot stops answering after a hundred questions —
or, worse, one person exhausts it for everyone by lunchtime.

The service is the only component that knows **who** is asking. So the per-user quota belongs there,
and the Worker gets a `discord` client mode with a ceiling sized for a server rather than a browser.

## What to build

- Per-Discord-user counters in the service — a short window and a daily one, mirroring the shape the
  Worker already uses.
- A global daily ceiling for the whole bot, so a bad day has a known cost and a known end.
- When a limit is hit, the bot **says so** with when it resets. A bot that goes quiet is
  indistinguishable from a bot that is broken — and this is the same failure the CI monitors had.
- Counters that survive a restart, or degrade to something stricter rather than resetting to
  unlimited. Fail closed, as decided for the Worker.
- The `discord` client mode consumed on the Worker side, per
  [`FEAT-SUPPORT-LOG-ANALYSIS` ticket 02](../../FEAT-SUPPORT-LOG-ANALYSIS/tickets/02-worker-multi-client.md).

## Notes

- The audience is the VEAF Discord open to the DCS public, so the quota is the only thing standing
  between an unknown visitor and the free-tier ceiling that also serves the documentation widget and
  the CLI. Sizing it is a real decision, not a placeholder.
- These counters are reused, with a much lower ceiling, by
  [`FEAT-SUPPORT-BUG-INTAKE`](../../FEAT-SUPPORT-BUG-INTAKE/PRD.md). Build them once.

## Definition of done

- [x] Per-user short-window and daily counters
- [x] Global daily ceiling, configurable, with its value documented
- [x] A refused request answers with the reason and the reset time
- [x] Restart does not silently reset counters to unlimited
- [x] `discord` client mode used against the Worker
- [x] Unit tests: per-user limit, global limit, restart behaviour, message rendering
- [x] Quality gate clean
