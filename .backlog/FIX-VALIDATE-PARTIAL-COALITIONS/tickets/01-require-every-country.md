# 01 — Require every unit-owning country to be assigned

Status: ⬜ ready

Type: fix · Files: `src/python/veaf-tools/veaf_libs/mission_validator.py`,
`veaf_libs/locales/{en,fr}.json`

## The change

`_check_coalition_countries` currently asks "is this side's list empty?". It must ask "does this
side's list contain every country that owns units?", and name those it does not.

The existing message (`validate.side_without_country`) stays for the empty case — it explains the
consequence well. Add a second string for the partial case, naming the missing country ids.

## Watch the shape of the data

`coalition.<side>.country` is a DCS 1-based table that may come back as a dict or a list — the
existing code already goes through `indexed()` for exactly that reason. `coalitions.<side>` is a
list of country **ids**, while the countries under `coalition.<side>.country` are dicts carrying
their `id`. Compare ids, not positions.

Only countries that actually own units matter: `CATEGORIES` in that module is the list of group
categories the check already walks.

## Definition of done

- [ ] Partial assignment is reported, with the missing ids in the message
- [ ] Full assignment is silent
- [ ] The empty case keeps its current message
- [ ] A country owning no units is never required
- [ ] Tests for all four cases, on the table shape a real `.miz` produces (dict-keyed, 1-based)
- [ ] Run it over the local Foothold missions, read-only, and report what it says — a check that
      lights up on missions in service is a finding, not a failure
- [ ] `poetry run pytest`, ruff, mypy clean (`poetry install --without build --all-extras` first,
      or the coverage figure is wrong)

## Context worth reading first

PR #868 fixed the two producers (`aircrafts_injector._get_or_create_country` and
`coalition_placeholder.py`) and added `test/python/test_prepare_theatre_build_validate.py`, which
asserts this invariant **directly** rather than through `validate` — precisely because `validate`
was too weak. That test is the specification for this ticket; the point here is to move the
invariant into the validator so any mission benefits, not only the one that test builds.
