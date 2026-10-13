# 01 — `list_payloads` knows no WW2 aircraft, and no module aircraft at all

Status: ✅ done
Type: fix (data)
Files: `veaf_build/dcs_data/payloads.py`, `src/python/veaf-tools/veaf_libs/data/payloads.yaml`, `veaf_libs/dcs_payloads.py`, tests

## What happens

`list_payloads` answers « DCS has no named loadout for 'P-51D' » for P-51D, P-51D-30-NA, P-47D-30, P-47D-40, SpitfireLFMkIX, MosquitoFBMkVI, Bf-109K-4, FW-190A8, FW-190D9 (every WW2 module aircraft), and for the two AI bombers a Normandy mission needs, Ju-88A4 and B-17G. The tool's own description says « a module aircraft has none here: give it pylons or loadout_from » — and the shipped `veafSpawn-*` / dynamic-slot templates of these types carry `pylons: {}`, so `loadout_from` fails too (« the group 'P-51D Template' carries no pylons »).

Cause, read in the code: `payloads.py` reads only `MissionEditor/data/scripts/UnitPayloads/` (`PAYLOADS_SUBDIR`). Module aircraft keep theirs under `CoreMods/<module>/UnitPayloads/`: on this workstation `c:/jeux/DCS World/CoreMods/WWII Units/UnitPayloads/` holds `P-51D.lua` (« Fuel75*2 », « HVAR*6,Fuel75*2 »…), `P-47D-30.lua`, `P-47D-40.lua`, `SpitfireLFMkIX.lua`, `MosquitoFBMkVI.lua`, `Bf-109K-4.lua`, `FW-190A8.lua`, `FW-190D9.lua`, `A-20G.lua`. The AI bombers have no such file: their stations are only in the install's `db.Units.lua` (`Ju-88A4`: pylons 1 and 3 `SC_501_SC500`, pylon 2 `{JU88A4TORP_10xSC50_on_InvCountedAttachmentPoints}`; `B-17G`: pylon 1 `{12xM64}`).

The Normandy Open Training read the two bombers' CLSIDs from `db.Units.lua` by hand (`tools/gen_10_joueurs.py` of the mission folder).

## What ships

- `update-dcs-data --payloads` also walks `CoreMods/*/UnitPayloads/*.lua` (same parser), keyed by `unitType` as before.
- For AI types with no payload file, a second source: the stations of `db.Units.lua`. One default per station is not a « named loadout » — either list the CLSIDs per station so an agent can build `pylons`, or name a few obvious defaults. Pick the cheaper; say which.
- `list_payloads` with no type lists these types too; the module-aircraft sentence of its description goes.
- Regenerate `payloads.yaml` from a full install (Core + CoreMods) and commit it.

## Done when

`list_payloads(unit_type="P-51D")` names `Fuel75*2` and `HVAR*6,Fuel75*2` with their pylons; `add_air_group(unit_type="P-51D", payload="HVAR*6,Fuel75*2")` writes the eight stations. Ju-88A4 and B-17G answer with at least their bomb loads.

## Done

`update-dcs-data --payloads` also walks `CoreMods/**/UnitPayloads`; the table went from 45 to 129 types (2 164 loadouts, nothing lost or changed). The files are not all data: seven module files compute their CLSIDs from `local` names (AH-64D, F-100D, three F-14A, F-14B, MiG-29 Fulcrum), which the parser cannot read; the generator lists them and leaves those types out, after neutralising the `tasks` tables that hold identifiers (that read five more).

Two corrections to the finding: the files sit under `CoreMods/aircraft/<module>/UnitPayloads` and `CoreMods/WWII Units/UnitPayloads`, and the Spitfire has **no** loadout file anywhere in the install (it stays without a named loadout). The AI bombers' stations are in `db.Units.lua`, which the generator does not read (a 39 MB dump of this workstation, not something every install has): the cheaper source chosen is a small hand-written file, `veaf_libs/data/payloads-ai-bombers.yaml` — `Ju-88A4` « SC500*2,SC50*10 » and `B-17G` « M64*12 », the loads the Normandy raids fly — merged by `dcs_payloads` and bundled in the executable.
