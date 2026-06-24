# Lot FIX-SPAWNABLES-CATEGORY — default spawnables mis-categorize planes as helicopters

Status: ✅ done

**Goal**: the shipped default `src/defaults/mission-folder/src/spawnables.yaml` files all 50 fixed-wing CAP templates (F-15C, M-2000C, MiGs, …) under the **`helicopters:`** category (`airplanes:` was empty before the MQ-9 restore). The build injects them faithfully → in the `.miz` they land under the country's `helicopter` group table instead of `plane`. Confirmed in a built mission. The current `extract-aircraft-groups` tool categorizes correctly (it put the MQ-9 under `airplanes`), so this is a **stale extraction artifact** baked into the committed default, not a live tool bug. Found during DCS-UPDATE-VERIFY (R3-FINDING-2) and spun off. **TBD**: (1) confirm whether the wrong category actually breaks CAP spawning at runtime or veaf re-derives it from the unit type (sets priority); (2) regenerate / re-categorize the default set under `airplanes`; (3) check the source the default was generated from.

**Branch**: `fix/spawnables-category` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SPAWNCAT-001 | Confirm runtime impact, then re-categorize the default CAP templates from `helicopters` to `airplanes` (regenerate via `extract` if that's the clean source); regression test asserting planes land under `airplanes` | `src/defaults/mission-folder/src/spawnables.yaml`, `test/python/` | fix | ✅ |

**Outcome**: confirmed **not cosmetic** — the CAP spawn path (`veafSpawnAircraft.lua` → `mist.teleportToPoint` clone → `mist.dynAdd`) never re-derives the category, so `coalition.addGroup` receives `Unit.Category.HELICOPTER` for fixed-wing units. Regenerating from the source mission was rejected (the extractor reflects the source `.miz` faithfully, so a mis-categorized source would reproduce the bug). Fixed with a category-aware migration keyed on the canonical `dcsUnits.yaml`: all 50 templates moved `helicopters:` → `airplanes:` (none was a real helicopter), 51 group bodies preserved byte-for-byte. New `test_spawnables_defaults_category.py` guards both the shipped data (both directions) and the injector bucket → DCS-table mapping.
