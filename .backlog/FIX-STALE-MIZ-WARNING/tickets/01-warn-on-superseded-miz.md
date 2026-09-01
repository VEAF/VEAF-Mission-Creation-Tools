# 01 — Warn when a previous build is left beside the new one

Status: ✅ done

Type: fix · Files: `tools/Get-SupersededMiz.ps1` (new), `tools/Convert-FootholdBatch.ps1`

## The defect

`Test-MizNaming` splits the `.miz` files into `Matching` (they start with the expected base name)
and `Stale` (they do not). Yesterday's build starts with the expected base name too — only the
date suffix differs — so it lands in `Matching` and nothing is reported.

## The fix

`Get-SupersededMiz` takes the matching names and returns those that are earlier builds: group by
base name **and** variant, keep the latest date per group, report the rest. The batch prints one
warning per file, alongside the existing differently-named-file warning.

Its own dot-sourced file, like `Resolve-MissionFolder.ps1`: `Convert-FootholdBatch.ps1` takes
mandatory parameters, so a test cannot source it without starting a conversion.

## Definition of done

- [x] Two builds of the same mission, different dates → the older one is named in a warning
- [x] Two variants of the same day → nothing reported (that is one build, not two)
- [x] A variant is compared against its own previous build, not another variant's
- [x] A `.miz` with no date in its name is left alone
- [x] The batch actually calls it — asserted on the script's syntax tree, not on its text
- [x] Verified against the real mission folders: the five refreshed on 2026-08-25 are flagged,
      the five that were not are silent
