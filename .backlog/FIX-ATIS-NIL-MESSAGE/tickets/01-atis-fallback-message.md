# 01 — Words instead of a nil, and a floor under every message

Status: ✅ done
Type: fix
Files: `src/scripts/veaf/veafWeather.lua`, `src/scripts/veaf/veaf.lua`, `src/scripts/veaf/veafI18n.lua`
(or wherever the ATIS keys live), `test/lua/test_veafWeather.lua`, `test/lua/test_veaf.lua`

Credit: **MacFlorent**, PR #303 — this is the half of his change that was never picked up.

## Tasks

- [ ] `veafWeather.messageAtcClosestAirbase` emits a translated "no ATIS available for <airbase>"
      instead of passing `getAtisString`'s `nil` to `veaf.outTextForUnit`.
- [ ] `veaf.outTextForUnit` refuses a nil or blank message rather than forwarding it to
      `trigger.action.outTextForUnit` / `outTextForGroup` / `outText`. Log it, since a caller with
      nothing to say is usually a bug in the caller, and silence would hide it.
- [ ] i18n keys in **both** languages — the message is read by a pilot in the cockpit.
- [ ] Tests: the ATIS path with a vanished airbase returns words; the message floor drops a nil and
      logs; a normal message still gets through unchanged.

## Why the floor and not just the caller

There are dozens of `outTextFor*` callers. Fixing only the ATIS one leaves the same trap armed for
every other, and the failure mode is the worst kind — a **DCS scripting error raised from a display
call**, which reads in `dcs.log` as a weather bug rather than as "somebody passed nothing".

The floor must **log** rather than silently swallow: a caller reaching it has a defect, and a silent
no-op would turn a visible crash into an invisible absence. That is the trade this lot's PRD warns
about — silence is worse than a crash for whoever has to diagnose it.

## Acceptance criteria

- [ ] `poetry run test-lua` green, including the new tests.
- [ ] `stylua --check src/scripts/veaf/` clean; `luacheck` clean (CI).
- [ ] Lua coverage floor raised if measured coverage moved more than ~2 points above it.
- [ ] `CHANGELOG.md` entry crediting MacFlorent and naming issue #302 / PR #303.

## The trap to avoid

MacFlorent's own version hardcoded the English sentence. Every user-visible string here goes through
`veaf.t`, so copying his line verbatim would fix the nil and introduce an untranslated message — trading
one defect for a smaller one. Use the i18n mechanism.
