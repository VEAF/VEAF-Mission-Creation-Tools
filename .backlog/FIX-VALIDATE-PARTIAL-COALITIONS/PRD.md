# FIX-VALIDATE-PARTIAL-COALITIONS — a check that only catches the empty case

Status: ⬜ ready

Origin: left open by `FIX-PREPARE-THEATRE-COALITIONS` (PR #868), which fixed the producers and
found the check too weak to have caught them.

## The gap

`_check_coalition_countries` (`veaf_libs/mission_validator.py:198`) reports a side only when its
country list is **entirely empty**:

```python
if has_units and not indexed(assigned.get(side) if isinstance(assigned, dict) else None):
```

DCS's requirement is stronger: **every** country that owns units under `coalition.<side>.country`
must appear in `coalitions.<side>`. A mission with one country assigned out of three passes
`validate` and still opens the coalition assignment screen — refused, with a green check behind it.

That is not hypothetical. The defect PR #868 fixed produced exactly that shape: six unit-owning
countries, none assigned. Had the generator been "fixed" by declaring a single country — one of the
two options weighed there — `validate` would have gone quiet while five countries stayed unassigned
and DCS kept refusing the mission. The check would have hidden the bug it exists to catch.

## The invariant to enforce

For each side: `{countries owning units} ⊆ {countries listed in coalitions.<side>}`, and name the
missing ones in the message. PR #868's test already asserts this directly — it reports
`side 'blue': countries [2, 5, 80] own units but are not listed in coalitions.blue ([])`. Reuse that
formulation; a message naming the country ids is what makes the error fixable.

## Why this is safer than it sounds

The concern when it was left open was that the same check runs during `build`, so tightening it
could change what existing missions may build. It does not: the build **collects** these into
`_reference_issues` for its end-of-run summary and does **not** abort — see
`mission_builder_worker.py:1405-1407`, and the summary the guide describes as printed "sans
bloquer". A tightened check therefore adds lines to a report; it stops no build.

Say that in the PR. Someone will otherwise assume the opposite, as we did.

## Definition of done

- [ ] A side with some countries assigned and some not is reported, naming the missing ids
- [ ] A side with every unit-owning country assigned stays silent
- [ ] The existing empty-list case keeps its behaviour and its message
- [ ] A country with no units is not required to be listed — DCS does not care, and demanding it
      would produce noise on perfectly good missions
- [ ] Run the tightened check over the real missions available locally
      (`D:\dev\_VEAF\VEAF-Foothold-*`, read-only) and report what it now says: if it lights up on
      missions that fly today, that is a finding worth having before merging

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Require every unit-owning country to be assigned](tickets/01-require-every-country.md) | fix |
