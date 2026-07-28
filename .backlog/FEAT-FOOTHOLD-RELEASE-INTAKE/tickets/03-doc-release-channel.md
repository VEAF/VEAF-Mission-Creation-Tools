# 03 — Document the new release channel, external config and `Era` values

Status: ✅ done
Type: docs

## Why

`doc/mission-maker/FOOTHOLD.md` (+ `.en.md`) describes the moulinette against the old
distribution ("the upstream Foothold `.miz` for the target map") and an `Era` global with two
values. Three things it now gets wrong or omits, one of which is an operational trap.

## What to write

### a. Where the upstream comes from

Point at [leka1986/Lekas-Foothold](https://github.com/leka1986/Lekas-Foothold) releases, and
say the asset is a **zip** containing the `.miz` plus the Config Manager, the manual and a
shortcut. State that `convert-other` takes either the zip or the `.miz` (depends on ticket
02 — if 02 ships later, document the manual unzip and revisit).

### b. The external config channel (the trap)

`Foothold Config.lua` V1.0.9 loads `<Saved Games>/Missions/Saves/Foothold Config.lua` when
that file exists and overlays it on the `.miz` defaults, nagging on screen when tracked
settings are missing. That file is what the **Foothold Config Manager** installs.

State plainly, in the mission-maker doc **and** wherever we document server deployment:

- our `config_override` still wins, because `veaf-config-override.lua` is loaded *after* the
  config script — [ADR 0008](../../docs/adr/0008-foothold-config-override.md) is intact;
- but a `Foothold Config.lua` sitting in a server's `Saved Games\Missions\Saves\` silently
  changes every Foothold mission on that instance, VEAF ones included;
- so: **do not install the Config Manager's external config on a VEAF server**. Config lives
  in `mission.yaml`, versioned with the mission folder and validated at build time.

### c. `Era` and `FootholdLocale`

`Era` accepts `"Modern"`, `"Coldwar"`, `"Gulfwar"` (the Iraq Cold-War name) and `"Vietnam"`.
Document all four, and that a `VIETNAM` `build_variants` entry is available the same way
`MODERN` / `COLD_WAR` are. Document `FootholdLocale` (`"FR"` among ten locales) as the
setting that drives Foothold's on-screen language.

## Tasks

- [x] Rewrite the prerequisites + step 1 of `FOOTHOLD.md` / `FOOTHOLD.en.md` for the release
      channel.
- [x] Add the external-config section (mission-maker view + the server-side warning).
- [x] Update the Modern/Cold-War section for the four `Era` values and `FootholdLocale`.
- [x] Note in `CONVERT_OTHER.md` / `.en.md` that a Foothold upstream now arrives zipped.
- [x] Check whether the deployment/ops doc needs the same warning; add it there if so.
- [x] CHANGELOG entry (docs-only, no version bump unless another ticket in the lot bumps).

## Verify

Keep the FR and EN pages in step — same sections, same anchors, English anchors on both
(per the anchor convention from `DOC-GUIDE-ANCHORS`).
