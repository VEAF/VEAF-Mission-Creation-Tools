# 01 — `--update` leaves behind a script the upstream release removed

Status: ✅ done

Type: fix · File: `src/python/veaf-tools/mission_builder/other_converter.py`

## The defect

`convert-other --update` refreshes `src/scripts/` from the fresh upstream `.miz` and computes a
diff (`diff_scripts`, `other_converter.py:128-131`) whose `removed` set is exactly "scripts in the
folder the upstream mission no longer produces". Nothing acts on that set: the file stays on disk.

Because it stays, `mission.yaml` keeps pointing at a script that still exists, so `validate` finds
it, passes, and the build injects **the previous release's version** of it.

## Reproduction — Foothold Syria 4.7.0, 2026-08-25

Lekaa renamed the Syria setup script between releases:

```
upstream 4.7.0 : footholdSyriaSetupv2.lua      (328.4 KB)
mission folder : footholdSyriaSetup.lua        (304.9 KB, from the previous release)
```

After `convert-other <archive> VEAF-Foothold-Syria --profile foothold --update`:

```
?? src/scripts/footholdSyriaSetupv2.lua     <- added
   src/scripts/footholdSyriaSetup.lua       <- still there, unmodified, still in mission.yaml
```

`veaf-tools validate VEAF-Foothold-Syria` → exit 0. The build produced a `.miz` carrying the old
setup script and none of 4.7.0's. Caught only because the archive had been compared with the
folder beforehand.

## Why not simply delete

A `removed` script is not always stale: a mission maker may have added a script of their own to
`src/scripts/`, and `upstream` only ever describes what the loader triggers of the upstream `.miz`
reference. Deleting on that basis would eat somebody's work.

The distinction the code already has: `before` is what the folder held, `upstream` what the fresh
release loads. A file that was in `before` **and** referenced by the previous run's
`custom_scripts:` and is no longer upstream is stale; anything else is the mission maker's.

## Definition of done

- [ ] A script the upstream release no longer loads, and that the mission's own `custom_scripts:`
      referenced, is removed from `src/scripts/` — or kept and **named in the report** as needing a
      decision, if the safer half is preferred
- [ ] A script present in the folder but never referenced upstream nor by `custom_scripts:` is left
      strictly alone (test: a hand-added script survives an update)
- [ ] `validate` fails, rather than passes, when `custom_scripts:` names a script the upstream
      release stopped shipping — the green run is what made this expensive
- [ ] Regression test built on the real shape: same mission, one script renamed between two
      archives
