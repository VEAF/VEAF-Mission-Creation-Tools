# FEAT-BRIEFING-METAR — a briefing cannot show the weather it was built with

Status: ⬜ ready

Origin: [#40](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/40), 2021.

## The gap

The issue asks for a `${METAR}` variable usable in a mission briefing, and explains why it does not
survive: the mission is rebuilt from a compiled source each time, so anything typed into the briefing
by hand is overwritten.

Measured: the weather injector accepts a METAR as **input** (`metar:` in its configuration, or an ICAO
to fetch one), and there is no briefing substitution anywhere — no `${METAR}`, no placeholder pass over
the briefing text.

So the data exists at build time and never reaches the text a pilot reads.

## Scope

A substitution pass over the briefing, with `${METAR}` as its first variable. Worth designing as a
**mechanism** rather than one hard-coded token, since the same need will come back for the mission
name, the era, or the build date — but ship one variable, not a template engine.

Two things to check first:

- **Which briefing.** A `.miz` carries the briefing in `dictionary` (via `DictKey_descriptionText_`),
  not as plain text in `mission` — so the substitution belongs where that dictionary is written.
- **Per build variant.** A mission built in seven weather variants needs seven different METARs, so the
  substitution runs per variant rather than once.

## Definition of done

- [ ] `${METAR}` in a briefing is replaced by the weather the mission was built with
- [ ] Correct per build variant, with a test on two variants of one mission
- [ ] An unknown `${…}` is left alone rather than blanked — a briefing is player-facing text
- [ ] Documented, both languages
