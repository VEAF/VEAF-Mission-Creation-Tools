# 08 — The validator calls the tool's own output "unusual"

Status: ✅ done
Type: fix

Found by the `pr-code-review` of this lot's own PR, chasing a smaller claim: ticket 05 said `DTC`
would be added to the validator's known group keys. It measured what the validator actually says,
and the answer was much larger than `DTC`.

## The measurement

`AircraftGroupsYAMLValidator.validate()` run on the two **shipped** catalogues, before the fix:

| catalogue | field reported *unusual* | occurrences |
|-----------|--------------------------|-------------|
| `dynamic-slot-templates.yaml` | `dynSpawnTemplate` | 128 |
| `dynamic-slot-templates.yaml` | `uncontrollable` | 128 |
| `dynamic-slot-templates.yaml` | `DTC` | 4 |
| `spawnables.yaml` | `hiddenOnPlanner` | 1 |
| `spawnables.yaml` | `hiddenOnMFD` | 1 |

**262 messages, and every one of them is noise.** `dynSpawnTemplate` is the flag that *defines* a
dynamic-slot template — `classify_aircraft_group` sorts the family on it. `hiddenOnPlanner` and
`hiddenOnMFD` are written by `_prepare_injected_group`, so the tool flags what it wrote itself one
step earlier. `uncontrollable` and `DTC` are ordinary DCS group fields the Mission Editor emits.

`_check_group_structure` lists the keys it knows and reports the rest at `info`, whose stated purpose
is *"this might be a typo or extracted metadata that should be removed"*. With 262 false ones, a
genuine typo arriving in that stream is invisible. This repository has the measurement for that
already, on a log written 124 lines a minute where its own comment claimed a few hundred per sortie.

## Why it belongs to this lot rather than a later one

The lot grafts 24 templates, each adding two more of those messages, and ticket 05 committed to the
`DTC` half of the fix. Doing only that half — silencing 4 while leaving 256 — would be cosmetic, and
it would leave the list still missing the field the family is defined by.

## What was done

The five measured fields are added to `common_group_keys`, with a comment recording the count and
why the tool's own output was missing from its own whitelist. No speculative entries: only what the
shipped catalogues actually carry.

## Definition of Done

- Both shipped catalogues validate with **zero** messages at any level, asserted by
  `ShippedCataloguesValidateSilentlyTest` — a ratchet, so the next field the extractor starts
  emitting has to be classified rather than added to the noise.
- The test fails without the fix, on both catalogues (verified by reverting).
- Nothing else in the validator changes: a field that really is unknown is still reported.
