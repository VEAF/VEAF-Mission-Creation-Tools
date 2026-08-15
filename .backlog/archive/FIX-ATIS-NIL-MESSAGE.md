# Lot FIX-ATIS-NIL-MESSAGE — a pilot asking for ATIS at a vanished airbase must get words, not a nil

Status: ✅ done

**Origin**: [PR #303 by MacFlorent](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/303)
(2026-01-20), for issue #302. That PR was closed as superseded — its crash fix landed independently in
`19cec379` — but it carried a second idea nobody picked up, and this lot is that idea. **Credit is
his.**

**Branch**: `fix/atis-nil-message`

| # | Ticket | Status |
|---|--------|--------|
| 01 | Words instead of a nil, and a floor under every message | ✅ |

## The bug was moved, not fixed

`veafWeatherAtis.getAtis` returns nil when the airbase's DCS object no longer exists — a sunk carrier,
a despawned base, a persistence reload. That guard is correct and *was* the fix for issue #302. What
was missing is what happens next:

```lua
local sAtcReport = veafWeatherAtis.getAtisString(veafAirbase)   -- may be nil
veaf.outTextForUnit(dcsUnit:getName(), sAtcReport, 30)          -- passed on unguarded
```

`veaf.outTextForUnit` hands its message straight to `trigger.action.outTextForUnit`, with no nil check
anywhere. So the crash issue #302 reported was **moved one level up**, from the computation to the
display. A pilot asking for ATIS near a destroyed airbase still tripped it — and it read in `dcs.log`
as a weather bug rather than as "somebody passed nothing".

## Fixed at two levels, deliberately

- **The specific one**: `messageAtcClosestAirbase` says something a pilot can act on — an i18n'd
  "no ATIS available for &lt;airbase&gt;" — instead of passing nil along. MacFlorent's idea, routed
  through `veaf.t`, because his version hardcoded English and every user-visible string here is
  localised.
- **The general one**: `veaf.outTextForUnit` **refuses a nil or blank message**, which puts a floor
  under dozens of callers.

Neither version was right on its own: one leaks a nil, the other bypasses i18n.

**The path had no coverage at all.** `test_veafWeather.lua` asserted nothing about `getAtis` or
`getAtisString`, which is why the gap survived a guard being added right beside it.
