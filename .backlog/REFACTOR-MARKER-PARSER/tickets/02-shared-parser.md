# 02 — Lift veafSpawnParser's machine into veaf.lua

Status: ⬜ ready
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

- [ ] Move the loop, `_num`/`_str`/`_flag`, and the unknown-key detection out of
      `veafSpawnParser` into `veaf.lua`, keeping `test_veafSpawnParser.lua` green **unchanged**.
      `veafSpawnParser` becomes the first client of its own machine, and this is the whole of
      migration step one.
- [ ] Design the specification table with ticket 01's quirk inventory in hand. A quirk that is
      deliberate has to be expressible, or the migration silently drops it — items 1, 2, 6 and 8
      are the ones that bite.
- [ ] Numeric conversion goes through `veaf.safeNumber` / `veaf.safeNumberInRange`; both exist and
      are tested. `veafSpawnParser`'s `_num` uses `veaf.getRandomizableNumeric`, which supports the
      `1-5` random-range syntax — that is a third numeric kind, not a bug, and the spec needs all
      three.
- [ ] Unknown keywords: keep `veafSpawn`'s behaviour, which reports them with a suggestion. It is
      better than the others' silence and is the one worth generalising.
- [ ] A bad parameter must never take the command down: it is ignored or defaulted, and said so.

## Acceptance criteria

- [ ] `veafSpawnParser` uses `veaf.parseMarkerText` and its own suite passes unedited.
- [ ] The shared parser passes ticket 01's tests for at least one further module before the
      migration proper starts.
- [ ] No `tonumber` call in the shared path outside `veaf.safeNumber`.
