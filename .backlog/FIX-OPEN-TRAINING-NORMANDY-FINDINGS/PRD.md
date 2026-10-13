# FIX-OPEN-TRAINING-NORMANDY-FINDINGS — what building the Normandy 1944 Open Training v6 through the MCP found

Status: 🔄 in-progress — tickets 01–06 and 08–13 done, 07 waits for DCS

Asked by David on 2026-10-13. The Normandy (WW2, 6 July 1944) Open Training v6 was built from scratch with the Open Training prompt (`.prompts/new-open-training-mission.fr.md`), the `veaf-mission-mcp` actions and the tools of `develop` (6.29.0), in `VEAF-Open-Training-Mission-Normandy-WW2-v6`. The prompt asks for a « Retours pour VMCT » block; this lot is that block. Every finding below was written down from the build; **read again in the code of `develop` before the work, six turned out to be wrong in part** (02, 06, 09, 11, 12, and 01's list of files), and each ticket says what was corrected.

It is the first WW2 mission built this way: the findings are mostly what an era with no tanker, no helicopter and no SAM, and aircraft with no named loadout, does to tools written for a modern theatre.

Findings first, in the order they did harm:

- the loadout oracle knows no WW2 module aircraft, and the AI bombers' bombs are only in the install's database (01), so every WW2 flight was either armed by hand or warned about (02);
- the shipped catalogue and the CAS tables ignore the era: 51 modern jets injected in a 1944 mission, a Bradley and an M4 rifleman in front of a Tiger (03, 04), and `list_shortcuts` says nothing about era (05);
- a Fw 190 cannot tune the VHF band the plan gives it (06) and the red slot templates may hold no cannon ammunition (07);
- the data and the commands around the DCS session: Normandy parking (08), a sweep that waits forever on a dead server (09), a limitations list too big for a tool result (10), a geocoder with no bounds for 8 theatres (11);
- the prompt itself (12);
- a group frequency of 251 MHz that the Mission Editor refuses on a P-51D or a Fw 190 client group, which the build never sees (13).

Not filed, already known and only recalled: `create_combat_zone` writes 20 km/h and an « Off Road » first point on convoy routes (Sinai retours 13; fixed here by editing the table, tools/gen_17_convois.py), the elevation grid being not shipped (Sinai 3), the missing `slim` step after `capture-map --parking` (Sinai 8), « Appuyez sur Entrée pour quitter… » from `inject-bridge` when called by a script (Sinai 10). `land.findPathOnRoads` finds no road from Vire: not VMCT, a property of the Normandy map.

| # | Ticket | Status |
|---|--------|--------|
| 01 | [`list_payloads`: module aircraft and AI bombers](tickets/01-payloads-for-module-aircraft.md) | ✅ |
| 02 | [« no weapons » on a gun fighter; `loadout_from` a gun-only template](tickets/02-no-weapons-warning-guns-only.md) | ✅ |
| 03 | [The spawnables catalogue ignores the era](tickets/03-spawnables-catalogue-ignores-era.md) | ✅ |
| 04 | [WW2 tables of `veafCasMission`](tickets/04-cas-mission-ww2-tables.md) | ✅ |
| 05 | [`list_shortcuts` has no era; WW2 radar and artillery aliases](tickets/05-shortcuts-have-no-era.md) | ✅ |
| 06 | [A radio role for a Fw 190 (38.4-42.4 MHz only)](tickets/06-fm-only-radio-role.md) | ✅ |
| 07 | [Red WW2 slot templates carry `gun: 0`](tickets/07-red-slot-templates-gun-zero.md) | 🧑 |
| 08 | [Ship the Normandy parking capture](tickets/08-normandy-parking-and-terrain-data.md) | ✅ |
| 09 | [`terrain-sweep` and a dead `dcs-serve`](tickets/09-terrain-sweep-dead-serve.md) | ✅ |
| 10 | [`describe_known_limitations` by area](tickets/10-known-limitations-by-area.md) | ✅ |
| 11 | [`theatre-bounds.yaml` covers four theatres](tickets/11-theatre-bounds-missing.md) | ✅ |
| 12 | [The prompt for eras with no support aircraft](tickets/12-prompt-for-eras-without-support.md) | ✅ |
| 13 | [`add_air_group` writes 251 MHz: the Mission Editor refuses to save a WW2 player group](tickets/13-air-group-frequency-in-radio-range.md) | ✅ |

Riskier than the rest, said in advance: 01 (new data from the install, two sources), 06 (the packer's band logic), 07 (needs DCS before a line is written).

Left to David: the Normandy elevation grid (1.2 MB) is not delivered, as no theatre ships its grid (ticket 08); the names of the six WW2 aliases (ticket 05); whether a Fw 190's primary frequency should be the first plan channel that fits it (ticket 06); the WW2 spawnable templates, which need the editor's own export (ticket 03).

One branch, one PR.

Source: the session that built the mission, `tools/retours-vmct.md` and the build logs of the mission folder.
