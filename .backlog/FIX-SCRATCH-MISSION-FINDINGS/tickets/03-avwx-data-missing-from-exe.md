# 03 — Real-weather fetch fails in the packaged exe

Status: ✅ done
Type: fix
Files: the PyInstaller spec / `veaf_build` exe build, possibly `dcs_weather_converter._fetch_live_metar`

## What happens

Every `airport_icao:` variant, in the 6.24.0 exe:

```
Échec de la récupération du METAR en direct pour ETAR : FileNotFoundError: [Errno 2]
No such file or directory: '...\Temp\_MEI000076702\avwx\data\files\stations.json'.
Utilisation des valeurs par défaut.
```

avwx's package data is not collected into the bundle. The build carries on with defaults and exits
0, so 11 of GermanyCW's 17 variants silently carry no real weather. The station is alive:
`tgftp.nws.noaa.gov/.../ETAR.TXT` answered on 2026-09-23.

Printed once only — later variants fail without a line — so the log understates it.

## Done when

- The exe fetches ETAR (collect avwx's data files: `--collect-data avwx` or the spec equivalent)
- A release smoke step runs one `airport_icao` fetch from the built exe
- A failed fetch is reported per variant, and the build summary says how many variants fell back

## Outcome (PR 1)

- `--collect-data avwx` in the exe build; the `exe-smoke` CI job checks `stations.json` is in the
  archive (network-free) — measured: 0 match on the 6.24.0 exe, 1 on the new one.
- The rebuilt exe fetched ETAR live (`BKN065 09/07 A3019` → Preset13, 1981 m, 9 °C, 766.8 mmHg).
- Each variant that falls back is named, and the weather step ends with a count.
