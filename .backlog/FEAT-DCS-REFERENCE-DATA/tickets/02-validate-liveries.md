# FEAT-DCS-REFERENCE-DATA-02 — validate liveries against the reference

Status: 🚫 wontfix — 2026-10-08

## What was planned

Ship the stock liveries per unit type with their allowed countries, and have the MCP warn about a livery DCS would not show.

## Why it is not done

The reference database does not read **zipped** liveries, and most module liveries ship zipped.
Measured on 2026-10-08 against `v0.5.0` and the install on DAVID-BUREAU:

| Type | Liveries in the install | In the reference |
|---|---|---|
| `F-16C_50` | 52 (`CoreMods/aircraft/F-16C/Liveries/F-16C_50`, mostly `.zip`) | 2 (`Dark_Viper`, `default`) |
| `FA-18C_hornet` | its folder exists | none mapped to the type |

A warning built on it would fire on most legitimate liveries.
Generating the table from an install instead (as `--payloads` does) was weighed and declined (David, 2026-10-08): a generator reading archives, outside the CI guard, covering only the modules installed where it runs.
The MCP keeps saying the livery is not validated, which stays true.

## Upstream report (draft, not posted)

> **Liveries shipped as `.zip` are missing from the reference data**
>
> `v0.5.0`'s `liveries` table lists 2 liveries for `F-16C_50` (`Dark_Viper`, `default`), where a DCS 2.9.30 install has 52 entries in `CoreMods/aircraft/F-16C/Liveries/F-16C_50`, most of them `.zip` archives (`13th_Fighter_Squadron.zip`, …).
> `FA-18C_hornet` has no livery mapped to it at all.
> It looks like the extractor walks livery folders but not zipped liveries, whose `description.lua` sits inside the archive.
> Reading them would make the table usable to validate a mission's `livery_id`.
