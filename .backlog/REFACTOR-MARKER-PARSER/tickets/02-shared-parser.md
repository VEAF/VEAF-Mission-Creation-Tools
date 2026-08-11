# 02 — Lift veafSpawnParser's machine into veaf.lua

Status: ✅ done
Type: feat

## Shape

`veafSpawnParser` already carries the parser this ticket used to ask for from scratch: a list of
command descriptors (keyphrase → seeded defaults), a list of parameter rules (keys → `apply`, with
an optional `when` predicate), a generic loop applying every matching rule, and unknown-key
reporting with a nearest-match suggestion. It is in production and covered by
`test_veafSpawnParser.lua`.

So this ticket **moves** that machine rather than inventing one. Into `veaf.lua`, beside
`veaf.safeNumber` and `veaf.safeNumberInRange`:

```lua
veaf.parseMarkerText(text, spec)
-- spec.commands   : { { match = "<keyphrase> group", init = function(options) … end }, … }
-- spec.parameters : { { keys = {"radius"}, apply = …, when = … }, … }
-- spec.defaults   : the options table's starting values
-- spec.separator  : "," by default; ";" for ArtilleryUnitHandler
-- spec.valueWhenAbsent : nil or "" — quirk 1, and it must stay expressible per module
-- spec.reportUnknownKeys : whether an unrecognised key is collected for the caller
-- spec.validate   : function(options) → boolean, the post-loop mandatory-field check
```

The point is that a module then **declares** its parameters instead of writing the loop, so a new
keyword cannot reintroduce `tonumber(nil) <= 5`.

## Tasks

- [x] Move the loop, `_num`/`_str`/`_flag`, and the unknown-key detection out of
      `veafSpawnParser` into `veaf.lua`, keeping `test_veafSpawnParser.lua` green **unchanged**.
      `veafSpawnParser` becomes the first client of its own machine, and this is the whole of
      migration step one.
- [x] Design the specification table with ticket 01's quirk inventory in hand. A quirk that is
      deliberate has to be expressible, or the migration silently drops it — items 1, 2, 6 and 8
      are the ones that bite.
- [x] Numeric conversion goes through `veaf.safeNumber` / `veaf.safeNumberInRange`; both exist and
      are tested. `veafSpawnParser`'s `_num` uses `veaf.getRandomizableNumeric`, which supports the
      `1-5` random-range syntax — that is a third numeric kind, not a bug, and the spec needs all
      three.
- [x] Unknown keywords: keep `veafSpawn`'s behaviour, which reports them with a suggestion. It is
      better than the others' silence and is the one worth generalising.
- [x] A bad parameter must never take the command down: it is ignored or defaulted, and said so.

## Acceptance criteria

- [x] `veafSpawnParser` uses `veaf.parseMarkerText` and its own suite passes unedited.
- [x] The shared parser passes ticket 01's tests for at least one further module before the
      migration proper starts.
- [x] No inline `tonumber` in the shared path. Restated honestly: the shared path converts only
      through `veaf.safeNumber`, `veaf.safeNumberInRange` and `veaf.getRandomizableNumeric`, and
      all three now return nil rather than raising. The original wording named only `safeNumber`,
      which would have excluded the random-range kind markers actually need.

## Delivered

`veaf.parseMarkerText(text, spec)` and `veaf.prepareMarkerSpec(spec)` in `veaf.lua`, with the four
`apply` kinds as `veaf.markerRules.{number, nonNegativeNumber, text, flag}` — the file-locals
`veafSpawnParser` used to own.

`veafSpawnParser` declares `veafSpawn.MarkerSpec` and its `markTextAnalysis` is now two lines.
**Its 71 tests pass with the file unedited**, which is the criterion that made the move reviewable:
`git diff` touches no test in that suite.

The specification expresses every load-bearing quirk from ticket 01: `valueWhenAbsent`
(nil vs `""`), `separator` (`,` vs `;`), first-match-wins command descriptors seeding per-verb
defaults, all-matching-rules-run with `when` gating, untrimmed values, opt-in unknown-key
reporting with a suggestion, and a post-loop `validate` for mandatory parameters. 27 tests.

### A root cause fixed rather than worked around a third time

Writing the shared helpers surfaced a real regression risk, caught by one of the new tests:
`nonNegativeNumber` had no nil guard, because inside `veafSpawnParser` `valueWhenAbsent = ""`
guaranteed a string. Shared, with nil as the default, the old crash was reachable again.

The guard is back in the helper — but the actual defect was one level down.
`veaf.getRandomizableNumeric_random(nil)` raised on `string.find(nil, "%-")`. `VMR-025`
**described that exact crash in a comment and then guarded against it in its caller**, which is
why `_numNonNegative` one function away walked into it, and why `FIX-MARKER-PARAM-CRASHES-2`
existed. It now returns nil at the source, so the guard cannot be forgotten by the next caller.
`_norandom` never had the problem.

### The differential harness ticket 03 will reuse

The second criterion asked the specification to express a module other than `veafSpawnParser`
before migration starts. Done as a **differential test** rather than an argument
(`TestVeafRadioSharedParserEquivalence`): the live parser and the shared parser run the same
37-input corpus and are compared field by field, so equivalence is measured. Two guards keep the
harness honest — one asserting the corpus is not empty, one proving a deliberately wrong
specification is caught.

That makes ticket 03's method concrete: build the spec, run the corpus, migrate only once it
matches. `veafRadio`'s spec is already written, and the equivalence confirms ticket 01's finding
that its `elseif` chain is unobservable.
