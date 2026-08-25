# 04 — `Convert-FootholdBatch -Update` cannot address an existing mission folder

Status: ⬜ ready

Type: fix · File: `tools/Convert-FootholdBatch.ps1`

## The defect

The batch derives each target folder from the archive's file name:

```powershell
$name = [System.IO.Path]::GetFileNameWithoutExtension($archive.Name)
$target = Join-Path $OutputFolder $name        # Convert-FootholdBatch.ps1:362-363
```

Lekaa's archive names carry the version (`Foothold_CA_4.7.0_Multi_Language_Coldwar-Modern-Vietnam.zip`),
and the VEAF mission folders are named after the map (`VEAF-Foothold-Caucasus`). So:

- `-Update` tests `Test-Path <target>\mission.yaml` (`:376`), finds nothing, and drops back to a
  **fresh adoption** — scaffolding a new `mission.yaml` beside a new folder instead of refreshing
  the tuned one;
- even against its own previous output, the next release has a different archive name, so a folder
  is created per release and `-Update` never engages.

## Why this bites rather than merely annoys

Every VEAF Foothold repository's README recommends exactly this command for a new Lekaa release:

```
.\tools\Convert-FootholdBatch.ps1 -InputFolder <download folder> -OutputFolder <missions folder> -Update -Build
```

Followed literally, it produces ten new folders and touches none of the ten missions.

The 2026-08-25 refresh worked around it by copying the five archives under the repository names
(`VEAF-Foothold-Caucasus.zip`, …) into a staging folder — profile detection reads the archive's
contents, not its name (`Get-ConversionProfile`), so the rename is safe. That workaround should not
be the procedure.

## Definition of done

- [ ] The batch can target mission folders whose names are not the archive names — a mapping
      (archive → folder), or matching an existing folder by theatre read from the archive, or an
      explicit pairs file; the theatre is already read for profile detection
- [ ] `-Update` engages on an existing mission folder in the same run that adopted a new one
- [ ] A folder is never created next to one it should have refreshed (the failure mode that is
      indistinguishable from success until someone reads `mission.yaml`)
- [ ] The mission repositories' README and `doc/mission-maker/FOOTHOLD.md` show a command that
      works as written
