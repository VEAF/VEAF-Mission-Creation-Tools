# FIX-ATIS-NIL-MESSAGE — a pilot asking for ATIS at a vanished airbase must get words, not a nil

Status: ✅ done
Branch: fix/atis-nil-message

Origin: **PR #303 by MacFlorent** (2026-01-20), for issue #302. That PR is closed as superseded —
its crash fix landed independently in `19cec379` (2026-05-16) — but it carried a second idea that was
never picked up, and this lot is that idea. Credit is his.

## Problem

`veafWeatherAtis.getAtis` returns `nil` when the airbase's DCS object no longer exists — a sunk
carrier, a dynamically despawned base, a persistence reload. That guard is correct and was the fix for
issue #302. What is missing is what happens **next**:

```lua
-- veafWeather.lua:1261
local sAtcReport = veafWeatherAtis.getAtisString(veafAirbase)   -- may be nil
if forUnit then
  veaf.outTextForUnit(dcsUnit:getName(), sAtcReport, 30)        -- passed on unguarded
```

and `veaf.outTextForUnit` hands its `message` straight to DCS:

```lua
-- veaf.lua
trigger.action.outTextForUnit(unitId, message, duration)        -- no nil check anywhere
```

So the crash issue #302 reported was **moved one level up**, from the computation to the display, rather
than eliminated. A pilot who asks for ATIS near a destroyed airbase still trips it.

MacFlorent's PR would have prevented exactly this by returning a sentence instead of nothing. His
version is not directly usable either: it hardcoded `"No ATIS message for airbase " .. name` in English,
and every user-visible string in this project goes through `veaf.t`. Neither version is right on its
own — one leaks a `nil`, the other bypasses i18n.

**No test covers this path.** `test_veafWeather.lua` asserts nothing about `getAtis` or
`getAtisString`, which is why the gap survived a guard being added right next to it.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Words instead of a nil, and a floor under every message](tickets/01-atis-fallback-message.md) | ✅ |

## Two fixes, deliberately, at two levels

**The specific one**: `messageAtcClosestAirbase` says something a pilot can act on — an i18n'd
"no ATIS available for <airbase>" — rather than passing `nil` along. That is MacFlorent's idea, with
the project's own translation mechanism.

**The general one**: `veaf.outTextForUnit` refuses a nil or empty message instead of forwarding it to
DCS. This is the floor that matters more than the instance: **no caller anywhere should be able to
raise a DCS scripting error by having nothing to say**, and there are dozens of callers. Fixing only
the ATIS path would leave the same trap armed for every other one.

Both, because either alone is unsatisfying: the guard without the message turns a crash into silence,
which is a worse bug than a crash for a mission maker trying to understand what happened; the message
without the guard fixes one caller out of many.

## Out of scope

- **Changing why the ATIS is unavailable.** A vanished airbase having no weather report is correct
  behaviour, not a defect to work around.
- **Auditing every `outTextFor*` caller** for other nil sources. The floor makes that unnecessary.
- Reopening the `getAtisString` contract: returning `nil` for "nothing to report" is a reasonable
  signal for a library function. The defect is in a consumer that treats it as a string.

## Definition of Done

- A pilot asking for ATIS at an airbase whose DCS object is gone receives a translated sentence.
- `veaf.outTextForUnit` and its group variant cannot reach `trigger.action.*` with a nil message.
- Tests cover both: the ATIS path returning words, and the message floor refusing a nil — the path
  that had **no** coverage at all before.
- French and English i18n entries, since the message is user-visible.
