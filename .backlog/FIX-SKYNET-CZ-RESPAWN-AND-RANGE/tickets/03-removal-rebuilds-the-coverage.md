# 03 — a removal rebuilds the coverage

Status: ✅ done

## The defect

The parent/child radar graph is built once, by `SkynetIADS:buildRadarCoverage`, when the network
activates. `veafSkynet.removeSkynetElement` takes an element out of `iads.samSites` and
`iads.earlyWarningRadars` — and leaves it listed as a **child** of every element that could see it.

Measured on Tripack's log, 10:03:13: three sites destroyed by command, one swept, and the EW radar
still announces `SAM SITES IN COVERED AREA: 5`, naming four elements that are no longer in the
network. `informChildrenOfStateChange` keeps commanding elements that have been cleaned up.

Introduced by #947: before the sweep existed, the only caller of `removeSkynetElement` was the
point-defence path, which does not run by default.

## What to build

- `veafSkynet.rebuildRadarCoverage(networkName)`: `iads:buildRadarCoverage()` through `pcall`, since
  it is called right after corpses have been dropped;
- call it from `removeVanishedSites` when the sweep actually removed something — once per sweep, not
  once per element.

## Done when

- a sweep that removes an element rebuilds the coverage
- a sweep that removes nothing does not
- a network with no IADS does not raise
- reverting the production change makes the new tests fail
