# CHORE-DROP-MACOS-INTEL — stop building a macOS Intel binary nobody ever received

Status: ✅ done — 2026-10-04 · archived 2026-11-24

Origin: David, 2026-10-04, after the 6.27.0 release run stayed open overnight.
The `Standalone veaf-tools-macos-x86_64` job of `release.yml` runs on `macos-13`, a scarce Intel runner pool.
On 6.27.0 it sat queued from 2026-10-03 20:40 while every other job had finished, and the run never completed.
It never shipped anything either: the 6.20.0, 6.25.0 and 6.26.0 releases carry the macOS **arm64** binaries and no `macos-x86_64` asset.

## Decision

- The release matrix drops the `macos-13` entry; Linux x86_64 and macOS arm64 remain.
- `platform_assets` no longer maps Darwin/x86_64 to an asset, so an Intel Mac gets the updater's existing "unsupported platform" warning instead of looking for an asset that does not exist.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Drop the macOS Intel target](CHORE-DROP-MACOS-INTEL.md) | ✅ |

## Tickets, in full

## 01 — drop the macOS Intel target

Status: ✅ done — 2026-10-04
Type: chore

Remove the `macos-13` / `veaf-tools-macos-x86_64` entry and its best-effort plumbing from the `standalone` matrix of `.github/workflows/release.yml`.
Remove `("darwin", "x86_64")` from `veaf_libs/platform_assets.py`, and pin in its test that Darwin/x86_64 is now unsupported.
