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

## Where the list comes from, and why that matters to the conversation

Until 2022-04-05 the helper did the exact opposite — `setActAsEW(**true**)` on SA-10, SA-6, Patriot
and Hawk — so the large systems watched permanently and saw for themselves. That is the behaviour
the 2026-09-17 reporter expects. It was removed on purpose:

| commit | date | author | |
|---|---|---|---|
| `a68dfd32` | 2022-04-05 | David Pierron | *"IADS: removed defaulting to EWR for SAM sites"* — flips the four to `false`, adds `Mcc-sr` false and `Ewr` true |
| `7ead5793` | 2022-05-20 | David Pierron | drops `Ewr` and `Mcc-sr` from the list |
| `3002aaad` | 2023-11-02 | Flogas | Skynet improvements |
| `d4e1b66c` | 2024-03-10 | Flogas | network deactivation |

So today's behaviour is a deliberate four-year-old VEAF trade-off, not a Skynet defect. The list
itself is defensible and this ticket does not propose dropping it — what is wrong is that it
overrides an **explicit** request, silently. Take that to the historical devs as a question about
the trade-off, not as a verdict.

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
