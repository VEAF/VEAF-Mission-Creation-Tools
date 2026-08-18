# FEAT-SLOT-WELCOME-BRIEF — greet a pilot taking a slot with the weather and the active runway

Status: ⬜ ready

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

## Definition of done

- [ ] A pilot taking a slot is told wind, weather and active runway
- [ ] The runway derived from wind, with a test on a couple of headings
- [ ] Localised, both languages
- [ ] Off by a setting, since a mission maker may run their own briefing
