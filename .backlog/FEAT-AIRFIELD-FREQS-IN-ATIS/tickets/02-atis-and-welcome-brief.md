# 02 — the ATIS and the welcome brief say the airfield's frequencies

Status: 🧑 waiting-human — the in-game check (R40)

Where a pilot meets an airfield in VEAF, nothing tells them how to call its tower: the welcome brief
(`veafWeather.buildWelcomeBrief`, on taking a slot) gives the runway and the weather, the ATIS
(`veafWeatherAtis.getAtisString`, from the F10 menu) the same.

## Done when

- Both add one line with the airfield's tower frequencies and TACAN from ticket 01, e.g.
  `Tower 260.000 UHF / 131.000 VHF / 40.400 FM — TACAN 16X`, translated (`veafI18n`), and nothing at all
  when the accessor returns `nil` (ship, FARP, unknown field) — never an empty or invented line.
- The band order and the formatting follow what a pilot dials; the number of decimals is checked against
  a frequency like 250.55 or 126.525, not only round ones.
- Lua tests on the mocks cover an airfield with all bands, one with VHF only, a ship and a helipad.
- Checked in DCS once: the welcome brief on a Caucasus slot and the ATIS from the menu show what the F10
  view shows for that field.
- The line is built so ticket 03 can add the mission's own channel beside it without rewriting it.
