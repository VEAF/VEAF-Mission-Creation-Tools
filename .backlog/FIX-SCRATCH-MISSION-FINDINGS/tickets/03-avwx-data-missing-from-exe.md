# 03 — Real-weather fetch fails in the packaged exe

Status: ⬜ ready
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
