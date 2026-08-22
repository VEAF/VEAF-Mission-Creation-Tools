# FEAT-BRIEFING-METAR — a briefing cannot show the weather it was built with

Status: ✅ done — shipped in 6.15.27

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

## Both "check this first" items confirmed

**Which briefing.** Confirmed: a `.miz` keeps the prose in the l10n dictionary and `mission` holds only a
key (`DictKey_descriptionText_1`). A substitution pass over `mission_content` alone would have found the
key and replaced nothing at all — the whole feature, silently doing nothing on any mission saved by the
DCS editor. Both shapes are handled, since a converted or hand-built mission can carry the text inline,
and a test pins that the key itself is never rewritten (substituting into it would rename the entry and
lose the briefing outright).

**Per build variant.** Confirmed and implemented inside `_create_mission_version`, which the weather
injector already runs once per `versions[]` entry — so seven weather variants get seven METARs. Two
variants of one mission are tested, exactly as the DoD asked.

## Scope decisions worth recording

**All four description fields**, not just the situation: `descriptionText` plus the three per-coalition
tasks. A mission maker writing `${METAR}` in the blue task has no reason to expect different behaviour,
and covering one field of four is the kind of half-feature that reads as a bug.

**A mechanism, and a small one.** `veaf_libs/briefing_variables.py` takes a plain name→value mapping, so
the mission name or the build date is a new entry rather than new code. Deliberately absent: expressions,
conditionals, nesting. A test pins that a replacement value containing `${…}` is **not** re-expanded — a
METAR is data, and data that happens to contain a token must not be interpreted.

**Three sources of METAR, and the honest answer for the third.** `metar:` gives the string directly;
`airport_icao:` fetches the live text; a variant built from `weather:` parameters alone has **no METAR
that exists**, so the token is not supplied and survives as written, with a warning naming it. Blanking
it was the alternative and it is worse: a hole in player-facing text reads as the build eating the prose.

**The ICAO fetch is conditional.** `fetch_metar_string` is a second function rather than a field threaded
through the weather conversion, precisely so it can be called *only when the briefing asks*. A build that
never writes `${METAR}` makes no network call, and a test asserts that.

Along the way the `versions[]` reference gained its missing `airport_icao` row — the field is read by the
build and was documented nowhere, which mattered here because `${METAR}` depends on it.

## Definition of done

- [x] `${METAR}` in a briefing is replaced by the weather the mission was built with
- [x] Correct per build variant, with a test on two variants of one mission
- [x] An unknown `${…}` is left alone rather than blanked — pinned by tests on both the unknown-name case
      and the known-but-unsupplied one
- [x] Documented, both languages
