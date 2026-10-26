# 05 — Check on dcs.veaf.org

Status: ⬜ ready

Blocked until the log routes run on dcs.veaf.org: DCSServerBot 3.0.5 released by SpecialK with them, or a backport on our `veaf` branch.
Read-only; David, or a session with his go.

- Open a running instance's `dcs.log` and the bot's log through the API, leave them open across a mission restart: the tab follows the new `dcs.log`, the end of the old one is not lost.
- Open an older `dcs-YYYYMMDD-HHMMSS.log`.
- Compare with the same instance opened over SSH: same entries, same categories, for the same span.

## Done when

- The three points seen, the result written in the PRD's findings.
