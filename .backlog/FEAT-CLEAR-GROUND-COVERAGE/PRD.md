# FEAT-CLEAR-GROUND-COVERAGE — widen the clear-ground catalogue where missions are built

Status: ⬜ ready

Origin: two AI-built missions on 2026-10-22 (Caucasus around Zugdidi, GermanyCW on the Werra) got "no clear-ground catalogue covers this place": the shipped catalogues are surveys of chosen places only — the Caucasus's 21 airfields, GermanyCW's 25 Open Training zones, nothing on the other theatres — so a unit placed anywhere else cannot be moved off trees and buildings.
Needs a survey flown in DCS (`veaf-tools dcs clear-ground-sweep`), so David's machine and his time; it is not part of [FIX-DEMO-VIDEO-FINDINGS](../FIX-DEMO-VIDEO-FINDINGS/PRD.md), which only makes the warning say what is covered.

## What to decide, then do

1. **Which places, per theatre.** Candidates: round every airfield, round the towns and the main road axes where a convoy or a depot goes, round the places the campaigns use. Measure what the AI-built missions asked for first (the zones of both sessions are the first two cases).
2. **A weight budget.** The Caucasus's 21 airfields weigh 258 KB, GermanyCW's 25 zones 317 KB; each added layer grows the executable. Fix a ceiling per theatre before surveying.
3. **Survey and publish.** One sweep per theatre, the catalogue regenerated, shipped with the next release; the limitation entry's text says what is now covered.
4. **A mission maker's own sweep** already wins over the shipped catalogue (`catalogue_for_theatre` reads the local one first, measured 2026-10-23): nothing to build, only to say in the guide that a mission maker can sweep their own place.

Measured 2026-10-23: each shipped layer is 6 km round a place (21 airfields on the Caucasus, 25 Open Training zones on GermanyCW), and the warning of the placement now names what the catalogue covers ([FIX-DEMO-VIDEO-FINDINGS](../FIX-DEMO-VIDEO-FINDINGS/tickets/12-clear-ground-coverage-message.md) 12).

Done when: the chosen places of the first theatres are surveyed and shipped, the weight stays under the ceiling, and the warning names the new coverage.
