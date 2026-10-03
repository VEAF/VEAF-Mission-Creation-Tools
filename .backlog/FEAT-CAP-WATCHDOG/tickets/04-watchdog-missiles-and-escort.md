# 04 — cruise missiles and escorts: decide first

Status: ⬜ ready — needs a decision before any code
Type: feature
Issue: [#187](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/187)

## Need

#187 also lists *"prise en compte des missiles de croisière"* and *"gestion de l'escorte"*, without
saying what either should do.

## What stands in the way

- **Cruise missiles**: `isCapEngageableTarget` keeps aircraft only, on purpose — the 2026-09-01 fix
  (`FIX-CAP-ENGAGES-PARACHUTES`) closed the door on everything airborne that is not an aircraft.
  Engaging a missile means opening that door for one category, and whether DCS AI fighters engage a
  cruise missile on an `EngageUnit` at all is to be measured.
- **Escort**: does it mean a CAP that protects a friendly group, or a CAP that prefers the escorts of
  a hostile package, or that leaves them alone? Each is a different change.

## Acceptance

A written decision for each item — built, or dropped with its reason — before ticket work starts.
