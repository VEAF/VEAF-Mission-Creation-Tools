# 04 — `_ICAO_<code>` in the mission file name (server-side real weather)

Status: ✅ done
Type: docs

## Why

David noticed the built `.miz` had lost the `ICAO` part of its name. It is not cosmetic: the
**RealWeather extension of DCSServerBot** reads `_ICAO_<code>` from the mission's **file name**
and fetches that airfield's live METAR at mission start. Losing the marker silently loses live
weather on the servers.

Working examples he gave:

```
VEAF_OpenTraining_Falklands_ICAO_SFAL_20250522.miz
VEAF_OpenTraining_Caucasus_ICAO_URSS_20251216.miz
MA_Foothold_GCW_V4.2.0_Modern_ICAO_EDFH.miz
```

Note `URSS` is **Sochi-Adler's ICAO code**, not "the USSR" — a wrong assumption made earlier in
the analysis and corrected by looking at the three examples side by side (`SFAL`, `EDFH`, `URSS`
are all four-letter codes).

This is a **different mechanism** from `veaf-tools`' own `airport_icao` in `versions.yaml`, which
fetches a METAR at **build** time and freezes it into the `.miz`. The server-side one re-evaluates
at every mission start, which is what a permanent server wants.

## Choosing a code: existing is not enough, it must be *fresh*

Two conditions: an airfield **on the theatre**, with a **live METAR station**. Checked every
candidate against NOAA rather than assuming, and the check paid off — the observation day is the
first two digits of the `DDHHMMZ` group:

| Theatre | Code | Airfield | Observation (day 28) |
|---|---|---|---|
| Caucasus | `URSS` | Sochi-Adler | 28 ✅ |
| Germany CW | `EDFH` | Frankfurt-Hahn | 28 ✅ |
| Persian Gulf | `OMDB` | Dubai | 28 ✅ |
| Syria | `OSDI` | Damascus | 28 ✅ (David's pick over Larnaca — on the map) |
| Sinai + Sinai North | `HECA` | Cairo | 28 ✅ |
| Iraq | `ORBI` | Baghdad | 28 ✅ |
| Kola | `ULMM` | Murmansk | 28 ✅ |
| Normandy | `LFRK` | Caen-Carpiquet | 28 ✅ |
| **Afghanistan** | **none** | — | every station stale |

Normandy was solved with David's suggestion: look through the theatre's airfield list
(`airdromes.yaml`, 90 entries) for one that still exists today. Heathrow, Orly, Jersey, Beauvais,
Deauville and Carpiquet all qualify; **Carpiquet** wins because it sits in the middle of the
combat area *and* reports.

Afghanistan is the interesting case: all 29 airfields were tested and **none** has a usable
station — Kabul a month behind, Herat 16 days, Bagram a day, and Maymana/Shindand/Bost/Farah/
Zaranj/Ghazni have no station at all (404). A stale METAR is worse than none, because the mission
then advertises a "real" weather that is days old. So that mission is named **without** the
marker, on purpose.

## Tasks

- [x] Apply `VEAF_Foothold_<Theatre>_ICAO_<code>` to the nine, and a marker-less name to
      Afghanistan.
- [x] Verify the produced file names carry `_ICAO_<code>_<date>.miz`, matching David's examples.
- [x] Re-validate the ten.
- [x] Document the convention in `MISSION_YAML_REFERENCE` (FR + EN): that the file name is an
      interface, the `_ICAO_` marker, the `.miz`-suffix trick for a date-less fixed name, and the
      one-line freshness check with the day-of-observation rule.
- [x] Re-take the mission.yaml backup.

## Notes

The naming convention was documented **nowhere** — it lived in the head of whoever set up the
servers. That is the real fix here; the nine names are just today's application of it.
