# FIX-BRIEFING-MAGNETIC-HEADINGS — the briefing's headings and bullseye bearings are magnetic

Status: ✅ done

Origin: pilots asking whether the bullseye bearings of "Marteau du Golan"'s briefing were true or magnetic (2026-10-29).

## Problem

`build_mission_briefing` and the campaign deck took every heading and bullseye bearing with `atan2` on the DCS `(x, y)` grid and printed it with no unit.
The grid is a Transverse Mercator projection: its north is neither true nor magnetic.
Measured on "Marteau du Golan" (Syria, `lon_0 = 39`), with the coordinates the briefing printed: W1 → W2 printed 073°, 71.3° true; W2 → W3 printed 321°, 319.4° true.
The 1.7 degrees are the meridian convergence at 35.8° E; the cockpit then takes another 5.2 of declination off.

## What the cockpits read

- **F-16C**: the bullseye "in degrees magnetic" (DCS F-16C Early Access Guide, HSD, FCR, HUD; a bullseye call over the radio is magnetic too).
- **F/A-18C**: magnetic headings on the HSI, the HUD and the radar unless TRUE is selected on the HSI DATA page (DCS F/A-18C Early Access Guide).
- **A-10C II** and **AH-64D**: their DCS manuals give the navigation headings magnetic and do not say for the bullseye (not verified).
- **The declination DCS uses**: the Mission Editor calls `magvar.init(date.Month, date.Year)` (`MissionEditor/modules/me_weather.lua`), with one World Magnetic Model coefficient file per five years, 1985 to 2025 (`Data/MagVar/COF`). Which epoch DCS takes for a date, and what it does before 1985 (it also ships `IGRF12.COF`), is inferred, not measured.

## Change

- `veaf_libs/magnetic.py`: the WMM declination at the mission's month and year (the coefficients vendored from DCS's, NOAA's public-domain files, bundled in the executable), the true bearing on the WGS84 ellipsoid, and their difference as `magnetic_bearing`.
- Magnetic, labelled `°M`, everywhere the briefing gives a direction: the legs of the flight plan (deck cards, PDF, kneeboard list and table), the bullseye of each step, objective and target, the bullseye from the departure, and the campaign deck's bullseye from its base.
- The carrier's course and the recon photos' heading (caption, banner, rose): the Mission Editor stores a unit's heading on its grid, shown as stored and turning its symbol on a map drawn in `(x, y)` (`me_ship.lua`, `me_map_window.lua`), and a DCS camera's axes are the world's (`camera_for`); both are turned to magnetic where they stand.
- `set_route` returns its legs magnetic and on the ellipsoid, as the briefing prints them.
- The ranges, everywhere above, on the WGS84 ellipsoid (within 2 cm of GeographicLib up to 550 km) instead of the grid, which overstated them by its scale: 0.1 % on the Golan, 1 % at Tbilisi.

## Tickets

- [01 — Magnetic headings and bearings in the briefing](tickets/01-magnetic-headings-and-bearings.md)
- [02 — Carriers, recon photos, set_route and ranges](tickets/02-carriers-recon-set-route-ranges.md)
