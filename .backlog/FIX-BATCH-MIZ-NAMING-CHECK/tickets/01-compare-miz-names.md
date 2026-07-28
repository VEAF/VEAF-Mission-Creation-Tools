# 01 — Compare the built `.miz` names with `mission.name`

Status: ✅ done
Type: fix

## Behaviour

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

## Tasks

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

## Notes

Deliberately **reports** rather than deletes. Removing a build artefact without being asked is the
kind of helpfulness that loses someone's file — the operator gets the name and decides.
