# FEAT-AIRDROMES-DUMP-UNION — the airfields DCS adds after the reference database resolve by name

Status: ✅ done

Asked by David on 2026-11-26, after reading the DCS 2.9.32.30490 release notes: "DCS: Cold War Germany Map … Added 20 new airfields" and "DCS: Kola map … Added Honningsvåg Airport, Hasvik Airport, Vardø Airport".

The airdrome table (`airdromes.yaml`, `airdrome-positions.yaml`) is generated from the `dcs-world-schema` reference database at `v0.5.0`, read on DCS 2.9.30.28536, and from the runtime dumps for a theatre the database lacks.
For a theatre the database knows, the database replaced the dump entirely, so a fresh capture could not bring a new airfield in: the 20 GermanyCW airfields stayed unknown to `airdrome_id_for_name`, and a dynamic-slot warehouse or a QRA `airport_link` naming one was not wired, with no error.
No newer reference database was published (latest `v0.5.0`, 2026-10-04).

Decision (David, 2026-11-26): join the two sources on the airdrome id. The reference wins on every id it has (name and reference point); a dump adds the ids it lacks.
The join is on the id because DCS keeps an airbase's id when it renames it: an older dump never brings an old name back beside the new one.
Measured before the new dump was copied: with the committed dumps, the join adds nothing (810 airfields before and after).

GermanyCW was captured again on DCS 2.9.32.30490 on 2026-11-26 (`capture-map --parking`, the bridge mission of 2026-10-22 with its two La-7 templates moved to 3.7 MHz): 247 airfields (+20, none gone, no id changed), 8 028 parking stands (7 035 before).
Kola is not installed on David's PC: its three new airfields wait for a capture elsewhere (`kola-airfields-added-by-dcs-2-9-32-unknown` in `known-limitations.yaml`, and the map list of the capture guide).

One ticket.
