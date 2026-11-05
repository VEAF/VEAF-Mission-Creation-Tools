# 02 — A profile removes Mission Editor groups

Status: ✅ done

A profile only changes configuration today (`veaf_libs/build_profiles.py`): no profile can take an AI flight placed in the Mission Editor, or a SAM placed by hand, out of its `.miz`.
This ticket adds a generic profile key, `remove_groups:` (names or `*` patterns), applied by the build to the mission table of that profile's `.miz`.
Ticket 03 uses it; it stands on its own for any profile.

## Done when

- A profile with `remove_groups: ["SA-10 *"]` builds a `.miz` without those groups, whatever their category (vehicle, plane, helicopter, ship, static) or their form (placed by hand, `#veafInterpreter` unit, combat zone group).
- A pattern that matches nothing is a build warning naming the profile and the pattern.
- A country left with no unit is handled as `coalition_placeholder` handles it: DCS purges an empty country on save.
- The build without a profile is byte-identical to the same build before the lot (test on a fixture mission).
- Tests assert on the built mission table, not on the profile mapping.
