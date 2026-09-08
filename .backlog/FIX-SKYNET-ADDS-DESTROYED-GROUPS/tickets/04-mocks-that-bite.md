# 04 — tests, and one that passes on broken code today

Status: ✅ done
Type: test

## The test that does not bite

`TestSecrev2RemoveSkynetElement:test_a_destroyed_group_does_not_raise` asserts that
`removeSkynetElement` survives an element whose group is gone. It passes. It would pass on the real
defect too, because the mock's

```lua
enableEmission = function(_) end
```

answers happily whether the object exists or not, while DCS raises on a destroyed one — and
`removeSkynetElement` calls `getDCSRepresentation():enableEmission(true)` with no guard at all. The
test asserts the handler, not the wiring: the same shape as the four defects shipped green on
2026-08-25.

Making the mock refuse to answer once `isExist()` is false is the point of this ticket, not a detail
of it: it is what turns three existing tests into a real check and what will fail on ticket 03's
code before it is written.

## What to cover

Ticket 01 — the init:

- a red group registered with `isExist() == false` is **not** enrolled, though
  `coalition.getGroups` hands it back
- a live group next to it in the same listing **is** enrolled — a guard that skips everything looks
  identical to a guard that works, on an empty network

Ticket 02 — the entry:

- a destroyed group returns `false` from `addGroupToNetwork` whichever caller passes it
- a `nil` group returns `false` instead of raising, which is what the existing unreachable guard
  claimed to do
- the three existing `TestVeafSkynetAddGroupToNetwork` cases stay green with no edit — the control

Ticket 03 — the sweep:

- a SAM site whose group was despawned (no death event) leaves `iads.samSites`
- a SAM site whose unit was reported lost (`S_EVENT_DEAD`) **stays**, so the SEAD readout survives.
  This is the assertion that makes the ledger load-bearing: drop it and a sweep that removes
  everything looks correct
- the network's `groups` entry goes with the removed site, so the name is free again
- an early-warning radar takes the same two paths
- `removeSkynetElement` on a destroyed object does not raise, **against a mock that raises the way
  DCS does**

## Definition of done

- [x] `dcs_mocks` group and unit doubles refuse the calls DCS refuses on a destroyed object
- [x] every case above asserted, in `test/lua/test_veafSkynetIadsHelper.lua`
- [x] each new suite verified to **fail** with its production change reverted, one at a time — not
      only to pass with it
- [x] `poetry run test-lua` green, and the coverage floor raised if the measure moved

## Measured

138 tests in the suite, all green. Each production change verified to fail on its own when reverted,
one at a time:

| reverted | tests that drop |
|---|---|
| the `dcsObjectStillExists` guard in `addGroupToNetwork` | 4 |
| the `enableEmission` guard in `removeSkynetElement` | 7, **including `TestSecrev2RemoveSkynetElement.test_a_destroyed_group_does_not_raise`** — the test that passed on the defect until the mock was made to refuse |
| removing from `iads.earlyWarningRadars` | 1 |
| the `lostUnits` ledger (`_wasReportedLost` forced to `false`) | 2, both *"a destroyed site is kept"* |
| the idempotence of `_armVanishedSitesSweep` | 1 |

Lua coverage: 80.50 % against a floor of 80, so the gate stays within the ~2-point tolerance and was
not moved.
