# 03 — A test that fails when the two lists drift apart again

Status: ✅ done

Type: chore · Files: `test/python/veaf_libs/test_module_init_registry.py`

The deliverable that outlives the lot. Without it the table is accurate for a week.

The test has to be on the Python side: it is the only place where both lists are visible at once — the
Lua registry is read from the sources, `_MODULE_INIT_ORDER` is a Python constant, and a Lua test can
see neither the generator nor the file tree.

## The rules it enforces

1. A module in `_MODULE_INIT_ORDER` **must** register, unless it defines no `initialize()` at all
   (`_NO_INIT_MODULES`). No exception list — the rule is derivable.
2. A module that registers **must** hold a place in `_MODULE_INIT_ORDER`, or be named in
   `UNORDERED_BY_DESIGN` with its reason in the doc.
3. `UNORDERED_BY_DESIGN` must hold no stale entry.
4. `_NO_INIT_MODULES` must name exactly the listed modules with no `initialize()`.
5. A module in neither mechanism is never initialised at all: it must be declared in
   `LIBRARY_MODULES`.
6. Self-initialising at load is a deliberate exception and must stay a declared one.
7. The table in `docs/agents/module-initialisation.md` is read back and compared, row by row, against
   the scan and the generator.

## Proof it can fail

Both directions were exercised on `GEO`, then reverted:

- adding `veaf.registerModule(veafGeo.Id, …)` with no generator counterpart →
  `test_every_registered_module_has_a_place_in_the_generator_order`,
  `test_modules_in_neither_mechanism_are_the_known_libraries` and `test_every_row_matches_the_sources`
  fail;
- adding `"GEO"` to `_MODULE_INIT_ORDER` with no registration →
  `test_every_module_the_generator_initialises_registers` and the same two others fail.

## Definition of done

- [x] Fails when a `registerModule` is added without its generator counterpart
- [x] Fails when a generator entry is added without its registration
- [x] Fails when the documented table stops describing the code
- [x] Every failure message names what to do about it
