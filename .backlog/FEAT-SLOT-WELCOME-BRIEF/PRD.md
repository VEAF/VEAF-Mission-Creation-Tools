# FEAT-SLOT-WELCOME-BRIEF — greet a pilot taking a slot with the weather and the active runway

Status: ✅ done

Origin: [#301](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/301), Tripack, 2025-12.
He points at the Foothold behaviour and attaches the script it uses.

## What exists, and what is missing

`veafWeather` already produces both a METAR and an ATIS report (`ToStringMetar`, and the ATIS
formatting beside it). So the content is not the work.

Missing: the **trigger** and the **runway choice**. Nothing greets a player on entering a slot, and
nothing decides which runway is in service from the wind.

## Scope

- fire on the player taking a slot (`onPlayerEnterUnit` through `veafEventHandler`, which already
  dispatches DCS events)
- a short message: wind, weather, active runway of the nearest airbase
- the runway from the wind, which is the only real computation here
- localised, per `FIX-RADIO-MENU-I18N`: this is player-facing text

Two things to settle: **which airbase** (the one the slot sits on, not the nearest in a straight
line), and whether it repeats on every slot change or once per session — Tripack's reference shows
it a few seconds after taking the slot.

## Delivered — 2026-08-24

### One correction to this PRD, which changed the size of the lot

It says *"nothing decides which runway is in service from the wind"* and calls that "the only real
computation here". It was in fact **the one part already written and shipped**:
`veafAirbase:getRunwayInService` picks the runway end with the best headwind, and the ATIS has been using
it. So there was no computation to write — the lot was the trigger, the airbase, the message and the
switch.

### What ships

A pilot taking a slot gets, five seconds later, a short message: the airbase, the runway in service
derived from the wind, and the weather. Sent to **his group** rather than his coalition — it is about his
airfield, and broadcast it becomes noise the moment two pilots take slots at different bases.

Deliberately shorter than the ATIS, which stays a radio command away: a greeting that fills the screen at
every slot change stops being read.

### The two open questions, answered

**Repeat or once per session: every slot entry.** A pilot who changes airfield wants the new airfield's
runway, and "once per session" would withhold exactly the case where the information changed.

**Which airbase: the nearest**, which for a pilot sitting at parking *is* the one he is on. The PRD asked
for "the one the slot sits on, not the nearest in a straight line", and the authoritative answer would be
the departure airdrome the mission declares on the group's first route point — but whether
`mist.getGroupRoute` carries `airdromeId` cannot be established without a running DCS, and guessing it
would be worse than using the tested helper. **Residual case**: a slot at one airfield marginally closer
to another's centre. Recorded rather than papered over, and worth a look next time DCS is up.

### A carrier announces its heading, not nothing

David's correction, and a domain point rather than a wording one: a carrier keeps no runway because it
turns into the wind, so what a pilot taking a deck slot needs is the **ship's course**. The first version
of this feature gave him nothing at all — and the tests were happy with that, which is the part worth
remembering.

The heading comes from `Airbase:getUnit(1)` (for a DCS ship the airbase *is* the vessel) and
`mist.getHeading(unit, true)`, the same call carrier operations already make in three places. The wording
is the carrier group's own — `carrier.atc_navigation` says *"Cap actuel (vrai)"* / *"Current heading
(true)"* — rather than a second vocabulary for the same number, also David's steer.

A helipad has neither a runway to align with nor a course to steer, so it gets the weather alone. And a
heading that cannot be read falls back to the weather rather than inventing one: a course a pilot cannot
trust is worse than no course, because he would fly it.

### Tests

19, and six mutations run against them: asking for the runway without the wind kills 1, giving a carrier a
runway kills 2, ignoring the setting kills 1, broadcasting to the wrong group kills 1, giving a carrier no
heading kills 2.

The sixth is the one worth recording. Asking for the **magnetic** heading instead of the true one killed
**nothing** at first: the stub ignored `mist.getHeather`'s arguments, so the flag was free to flip while
the message kept claiming "(true)". A brief lying by a magnetic declination is exactly the kind of defect
nobody reports, so the argument is now asserted and the mutation kills a test.

Two fixture defects on the way, both caught by a measurement that had already passed: the weather test did
not load `veafAirbases` or `veafEventHandler` at all, and one assertion searched for the runway digits
`"13"` and found them inside the QNH of `"1013"` — failing on a brief that was perfectly correct. Both
assertions now check the word rather than the digits.

### Documented

`veafWeather.md` / `.en.md` under `{#welcome-brief}`: the message, why it is delayed, why it repeats, what
a carrier and a helipad get instead, and the `welcomeBrief: false` switch.

## Definition of done

- [x] A pilot taking a slot is told wind, weather and active runway — and a carrier's heading instead of
      a runway it does not keep
- [x] The runway derived from wind, with a test on a couple of headings — the derivation was already
      shipped; what is tested is that the brief asks for it **with the wind** rather than without
- [x] Localised, both languages, reusing the carrier group's own vocabulary for the heading
- [x] Off by a setting, since a mission maker may run their own briefing — `WEATHER.welcomeBrief: false`
