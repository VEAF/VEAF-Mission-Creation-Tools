# 07 — geocode: one request a second, and a place rather than a street

Status: ⬜ ready

Files: `veaf_libs/geocoding.py`, the `geocode` action, tests.

## What happened

- Twenty-one `geocode` calls in a row: Nominatim answered 429 at the 21st, then refused every call, single
  ones included, for more than half an hour. Its usage policy asks for one request a second at most;
  `NominatimGeocoder.geocode` sends at once and does not read `Retry-After`.
- `limit: 1` takes Nominatim's first answer whatever it is: « Al-Kiswah » returned a street of Amman (inside
  the generous Syria bounds), « Latakia » the governorate's centre; « Morek, Hama », « Furqlus » and « Khan
  Arnabah » returned nothing.

## Done when

- At most one request a second per process; a 429 waits `Retry-After` (or a bounded back-off) once, then
  reports the refusal plainly instead of a raw `HTTPError`.
- The query asks for several candidates and prefers a settlement or a named place over a road or a region;
  the result carries the OSM class and type, and a `warnings` entry when the chosen one is a road or a
  region.
- Tests with recorded Nominatim answers (no network).
