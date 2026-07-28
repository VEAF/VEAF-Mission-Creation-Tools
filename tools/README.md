# `tools/`

Standalone helpers that are **not** part of the shipped `veaf-tools` product: they are run
from a clone of this repository, by hand.

Anything a mission-maker needs on their own machine belongs in the product instead (a
`veaf-tools` subcommand), because they receive the executable, not the repo.

| Item | What it is |
|------|------------|
| [`Convert-FootholdBatch.ps1`](Convert-FootholdBatch.ps1) | Adopts every Lekaa Foothold release archive of a folder in one pass, picking the right conversion profile per mission. See [FOOTHOLD](../doc/mission-maker/FOOTHOLD.md). |
| `klogg/veaf.conf` | Highlight rules for [klogg](https://klogg.filimonov.dev/), to read a DCS log with the VEAF lines standing out. |

Related: `scripts/` holds thin Python wrappers around `veaf_build` entry points.
