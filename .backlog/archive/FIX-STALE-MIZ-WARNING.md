# FIX-STALE-MIZ-WARNING — the previous build sitting beside the new one

Status: ✅ done · archived 2026-09-28

Origin: the product question `FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS` left open rather than
assumed, answered by David on 2026-08-31: **yes, it should warn**.

## The gap

`Convert-FootholdBatch.ps1` already compares the built `.miz` files with the name `mission.yaml`
asks for, and flags one under a *different* name. The reason is not tidiness: on the VEAF servers
that name is an interface — RealWeather reads `_ICAO_<code>` from it — so deploying the wrong file
silently pulls the weather of the wrong airfield.

It could not catch the other way of ending up with the wrong file. The build names its output
`<name>_<YYYYMMDD>[_<VARIANT>].miz`, so the previous build sits beside the new one under the
**same** base name and only the date differs. Both matched the expected name, so the check said
nothing.

Measured on David's mission folders, 2026-08-31 — five of the ten still carried their 2026-07-28
build next to the 2026-08-25 one:

| Mission | Left over |
|---|---|
| Caucasus | `VEAF_Foothold_Caucasus_ICAO_URSS_20260728.miz` |
| Germany | `VEAF_Foothold_GermanyColdWar_ICAO_EDFH_20260728.miz` |
| PersianGulf | `VEAF_Foothold_PersianGulf_ICAO_OIKB_20260728.miz` |
| Sinai | `VEAF_Foothold_Sinai_ICAO_LLBG_20260728.miz` |
| Syria | `VEAF_Foothold_Syria_ICAO_OLBA_20260728.miz` |

Exactly the five refreshed that day, and none of the five that were not.

## What makes it decidable rather than a guess

The date is in the name, and so is the variant. Group by name **and** variant; within a group,
only the latest date is the current build. That distinguishes the three cases that matter:

- `X_20260728.miz` beside `X_20260825.miz` → the first is a leftover;
- `X_20260825_MODERN.miz` beside `X_20260825_COLD_WAR.miz` → both current, which is precisely
  what `build_variants:` emits in one build;
- a `.miz` carrying no date → left alone. A hand-named file is not ours to judge, and the
  existing check already reports an unexpected name.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Warn when a previous build is left beside the new one](FIX-STALE-MIZ-WARNING.md) | fix |

## Out of scope

- **Deleting the leftovers.** The batch reports and does not remove; a built `.miz` may be the one
  currently deployed. The warning names the file and says why.
- **The same check inside `veaf-tools build`.** It would fit there, and would cover people who do
  not use the batch. Not done: the batch is where the ten-mission refresh happens, which is where
  the cost was paid.

---

## Tickets, in full

## 01 — Warn when a previous build is left beside the new one

Status: ✅ done

Type: fix · Files: `tools/Get-SupersededMiz.ps1` (new), `tools/Convert-FootholdBatch.ps1`

### The defect

`Test-MizNaming` splits the `.miz` files into `Matching` (they start with the expected base name)
and `Stale` (they do not). Yesterday's build starts with the expected base name too — only the
date suffix differs — so it lands in `Matching` and nothing is reported.

### The fix

`Get-SupersededMiz` takes the matching names and returns those that are earlier builds: group by
base name **and** variant, keep the latest date per group, report the rest. The batch prints one
warning per file, alongside the existing differently-named-file warning.

Its own dot-sourced file, like `Resolve-MissionFolder.ps1`: `Convert-FootholdBatch.ps1` takes
mandatory parameters, so a test cannot source it without starting a conversion.

### Definition of done

- [x] Two builds of the same mission, different dates → the older one is named in a warning
- [x] Two variants of the same day → nothing reported (that is one build, not two)
- [x] A variant is compared against its own previous build, not another variant's
- [x] A `.miz` with no date in its name is left alone
- [x] The batch actually calls it — asserted on the script's syntax tree, not on its text
- [x] Verified against the real mission folders: the five refreshed on 2026-08-25 are flagged,
      the five that were not are silent

---
