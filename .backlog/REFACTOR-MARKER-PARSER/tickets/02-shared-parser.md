# 02 — Build the shared parser against the characterisation tests

Status: ⬜ ready
Type: feat

## Shape

One parser, in `veaf.lua` beside `veaf.safeNumber`, taking a keyword specification per module:
the keyword name, its kind (flag / number / string / enumeration), its bounds, and its default.

The point is that a module then **declares** its parameters instead of writing the loop, so a
new keyword cannot reintroduce `tonumber(nil) <= 5`.

## Tasks

- [ ] Design the specification table with the quirks from ticket 01 in hand; a quirk that is
      deliberate has to be expressible, or the migration will silently drop it.
- [ ] Conversion goes through `veaf.safeNumber` — it already exists and is tested.
- [ ] Unknown keywords: keep whatever `veafSpawn` does today, since it already reports them to
      the pilot with a "did you mean" suggestion (`spawn.unknown_parameters`, `spawn.did_you_mean`).
      That behaviour is better than the others and is the one worth generalising.
- [ ] A bad parameter must never take the command down: it is ignored or defaulted, and said so.

## Acceptance criteria

- [ ] The shared parser passes ticket 01's tests for at least two modules before any module is
      migrated.
- [ ] No `tonumber` call remains in the shared path outside `veaf.safeNumber`.
