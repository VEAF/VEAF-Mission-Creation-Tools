# 12 — The clear-ground message says what the catalogue covers

Status: ✅ done

The sessions' warning, "no clear-ground catalogue covers this place on <theatre>", was read by the AI, and relayed to the user, as "GermanyCW has no terrain-object catalogue" (David's sandbox, Caucasus too). Measured in the repository: both catalogues ship since 6.26.0 — GermanyCW covers 25 trigger zones of the Open Training (Baumholder, Wahner Heide, Borkenberge, Brocken, the three convoy motorways…), the Caucasus covers 21 airfields. A place anywhere else is covered by neither; only a survey flown in DCS can change that.

Fix: the warning names what the theatre's catalogue does cover (its airfields and zones, or "none" for a theatre without one) and gives the sweep command ready to run for the place (`veaf-tools dcs clear-ground-sweep <theatre> --around X,Y`), in the language of the mission. The limitation stays recorded (`kind: tool`) because widening the catalogue is a survey, see FEAT-CLEAR-GROUND-COVERAGE.

Done when: the warning of `add_group`, `create_combat_zone` and `add_farp` carries the coverage and the command, with a test on a covered theatre and on one with no catalogue.

## Result

Measured: the GermanyCW catalogue holds 25 zone layers, the Caucasus one 21 airfield layers, 6 km round each (`known-limitations` entry `clear-ground-covers-what-was-swept`); a local sweep wins over the shipped one (`catalogue_for_theatre`). The warning already carried the `clear-ground-sweep … --around X,Y` command; it did not say what the catalogue covers.
Fix: `coverage_summary` names the number and the first places of the theatre's catalogue ("the GermanyCW catalogue holds 25 surveyed place(s) only (Baumholder_Easy, …)") or says the theatre has none; used by the placement of `add_group` and `create_combat_zone`, and by `add_farp`. The limitation entry says so.
