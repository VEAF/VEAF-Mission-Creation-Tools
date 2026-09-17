# 02 — An explicit EW-watch request is wiped by the next group joining

Status: ⬜ ready

## Problem

Marking a site as an EW watch (`setActAsEW(true)`) keeps it lit and lets it wake its neighbours.
It is the workaround a mission maker reaches for when there is no room for a real EWR, and it is
what the spawn option `ewr` asks for.

`veafSkynetIadsHelper.lua` then undoes it. Two places reset five NATO types unconditionally:

- [`addGroupToNetwork`](../../../src/scripts/veaf/veafSkynetIadsHelper.lua:1551), guarded by
  `not batchMode and not forceEwr and not pointDefense` — the guard covers *the group being added*,
  not the sites already in the network;
- [`buildNetwork`](../../../src/scripts/veaf/veafSkynetIadsHelper.lua:1636), after the enrolment
  loop, with no guard at all.

```lua
iads:getSAMSitesByNatoName("SA-10"):setActAsEW(false)
iads:getSAMSitesByNatoName("SA-6"):setActAsEW(false)
iads:getSAMSitesByNatoName("SA-5"):setActAsEW(false)
iads:getSAMSitesByNatoName("Patriot"):setActAsEW(false)
iads:getSAMSitesByNatoName("Hawk"):setActAsEW(false)
```

`getSAMSitesByNatoName` returns **every** site of that type in the network. So a SA-10 spawned with
`ewr`, or set to watch from `mission-script.lua`, reverts to silent the moment any other group
joins the network — a combat zone activating, a dynamic spawn, anything. Nothing is logged.

## What to decide, then build

The reset itself is defensible: those five are the systems a mission maker least wants emitting
permanently, and the line predates the `ewr` option. What is wrong is that it overrides an explicit
request and does so silently.

Recommended: record per site that its EW watch was asked for, and skip it in both resets. Failing
that, at minimum log at `info` when the reset turns off a watch someone requested — a silent
override is the failure mode the whole lot exists to remove.

## Definition of done

- A site marked as an EW watch keeps it, whatever joins the network afterwards, including the five
  named types.
- A test asserts it: mark a SA-10 as watch, add another group, assert the watch survives. Today
  that test fails.
- No behaviour change for sites nobody asked to watch.
