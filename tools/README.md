# `tools/`

Standalone helpers that are **not** part of the shipped `veaf-tools` product: they are run
from a clone of this repository, by hand.

Anything a mission-maker needs on their own machine belongs in the product instead (a
`veaf-tools` subcommand), because they receive the executable, not the repo.

| Item | What it is |
|------|------------|
| [`Convert-FootholdBatch.ps1`](Convert-FootholdBatch.ps1) | Adopts every Lekaa Foothold release archive of a folder in one pass, picking the right conversion profile per mission, and optionally validates and builds them all. See [FOOTHOLD](../doc/mission-maker/FOOTHOLD.md). |
| [`Sync-FootholdConfig.ps1`](Sync-FootholdConfig.ps1) | Reproduces the shared blocks of one tuned Foothold `mission.yaml` across the others, preserving each mission's own scripts, triggers and config target. Reports by default; writes only with `-Apply`. |
| [`foothold/`](foothold/) | Assets shared by the Foothold missions — the radio `presets.yaml`. |
| `klogg/veaf.conf` | Highlight rules for [klogg](https://klogg.filimonov.dev/), to read a DCS log with the VEAF lines standing out. |

Related: `scripts/` holds thin Python wrappers around `veaf_build` entry points.

## Conventions for the PowerShell scripts here

Two rules, both learned the hard way — a script that only runs on the author's machine is worse
than no script:

1. **Save as UTF-8 *with* BOM.** Windows PowerShell 5.1 — what `powershell.exe` is, and what a
   VEAF member has by default — reads a BOM-less `.ps1` as ANSI, so every accented character in a
   message turns into `Ã©`, `â†’`, and the file fails to parse. PowerShell 7 (`pwsh`) reads UTF-8
   regardless, which is exactly why this slips through when you only test there.
2. **Stay compatible with PowerShell 5.1.** No `??`, no `?.`, no `&&`/`||` between commands, no
   `-Parallel`. These are PowerShell 7 features and 5.1 rejects them at parse time.

Check both before committing:

```powershell
# Parses under 5.1? (not just under pwsh 7)
powershell.exe -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('<path>.ps1', [ref]$null, [ref]$null)"
```

Better still, run the script itself once with `powershell.exe -File` — parsing clean is not the
same as running clean.
