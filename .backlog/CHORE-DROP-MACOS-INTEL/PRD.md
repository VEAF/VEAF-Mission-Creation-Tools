# CHORE-DROP-MACOS-INTEL — stop building a macOS Intel binary nobody ever received

Status: ✅ done — 2026-10-04

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
| 01 | [Drop the macOS Intel target](tickets/01-drop-the-target.md) | ✅ |
