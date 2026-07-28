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
