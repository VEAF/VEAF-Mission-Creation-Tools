# 02 — Document dynamic slots and what limits them

Status: ✅ done

Type: docs · Files: the mission-maker docs covering `warehouses.yaml`, both languages

## Why

Two questions came out of the meeting, and one of them was purely a documentation gap: **how the
aircraft offered on a base are decided**. The mechanism is right and nobody could see it — nothing
is written in `warehouses.yaml`, the list is computed at build time from the dynamic-spawn template
groups present in the mission.

The other is the parking limit of ticket 01, which a mission maker has no way to guess: the tool
now stocks only what the terrain can park, silently.

## Definition of done

- [x] A page (or a section of the existing one) says plainly:
      - a base offers the aircraft that have a **dynamic-spawn template group** of its coalition in
        the mission — that is where the list comes from, and why `warehouses.yaml` is nearly empty;
      - an explicit `aircrafts:` list replaces that automatic choice;
      - DCS only ever offers what the airfield can **park**, so a helipad-only field offers
        helicopters whatever the stock says — with Lakatamia and Naqoura as the worked example, and
        how to check it (the slot picker in game);
      - the parking filter applies on the theatres with bundled parking data (Caucasus, Persian
        Gulf, Syria) and nothing changes elsewhere.
- [x] Both languages, in the `nav`
- [x] `poetry run docs-check` passes
