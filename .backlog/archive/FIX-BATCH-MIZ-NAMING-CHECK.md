# FIX-BATCH-MIZ-NAMING-CHECK — flag a built `.miz` whose name no longer matches mission.yaml

Status: ✅ done

## Context

While checking that the ten VEAF Foothold repositories matched their working folders, David asked
whether everything had been carried over. The repositories were byte-identical — but the **built
`.miz` files carried the previous ICAO codes**, because the codes had been corrected in
`mission.yaml` *after* the first build:

| Mission | `.miz` on disk | `mission.yaml` |
|---|---|---|
| Afghanistan | `_ICAO_OAIX` | `_ICAO_OPPS` |
| Persian Gulf | `_ICAO_OMDB` | `_ICAO_OIKB` |
| Sinai + Sinai North | `_ICAO_HECA` | `_ICAO_LLBG` |
| Syria | `_ICAO_OSDI` | `_ICAO_OLBA` |

Five missions whose configuration, repository and validation were all correct, and whose
deployable artefact pointed at the wrong airfield. Nothing reported it, because nothing compared
the output's **name** with the configuration.

That name is not cosmetic: DCSServerBot's RealWeather reads `_ICAO_<code>` from the file name to
fetch the live METAR at mission start (see the naming section of `MISSION_YAML_REFERENCE`).
A stale file therefore produces a mission that quietly uses the weather of another place.

The batch script also under-reported this: its "construit — N .miz" counted **every** `.miz` in
the folder, so a stale file inflated the count and looked like a successful extra variant.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Compare the built `.miz` names with `mission.name`](tickets/01-compare-miz-names.md) | ✅ |

## Why it belongs in the script rather than in the product

`veaf-tools build` writes one file and has no memory of previous runs; flagging leftovers is not
its job. The batch script, on the other hand, walks a folder per mission and is exactly where a
"what is in this folder now?" check belongs — next to the pre-build warnings it already emits.

---

## 01 — Compare the built `.miz` names with `mission.name`

Status: ✅ done
Type: fix

### Behaviour

After each build, `Test-MizNaming` reads `mission.name` from `mission.yaml` and sorts the `.miz`
files (folder root and `missions/`) into two groups:

- **matching** — name starts with `<mission.name>_`. Several is normal: weather and era variants
  suffix the base name. This is now what the "construit — N .miz" count reports.
- **stale** — anything else. Each is named in a warning, followed by one line telling the operator
  to delete them so the wrong file is not deployed.

Also warns when `mission.name` is set but **no** file matches it — a build that succeeded while
producing something unexpected.

No `mission.name` in the file → no comparison: the build then uses its own default name and there
is nothing to check against.

### Tasks

- [x] `Test-MizNaming` returning `@{Expected; Matching; Stale}`.
- [x] Count only matching files in the success line (it counted every `.miz` before).
- [x] One warning per stale file, plus the "delete them" hint.
- [x] Warning when the expected name matches nothing.
- [x] Read `mission.yaml` through `Read-Utf8Lines` — the UTF-8 helper, not `Get-Content`.
- [x] Parse `name:` case-sensitively and strip any trailing comment (the real files carry
      `# _ICAO_… lu par RealWeather (…)` after the value).
- [x] Verified end to end **under pwsh 7** (David's shell) with a deliberately stale
      `VEAF_Test_Normandy_ICAO_WRONG_20260101.miz`: the count says 1, not 2, and the stale file is
      named. Syntax also checked under Windows PowerShell 5.1.
- [x] Document in the script's comment-based help, `tools/README.md`, and the CHANGELOG.

### Notes

Deliberately **reports** rather than deletes. Removing a build artefact without being asked is the
kind of helpfulness that loses someone's file — the operator gets the name and decides.
