# 05 — the five aircraft that ship an autostart

**Status:** ⬜ ready — depends on 03.

`Macro_sequencies.lua` gives ED's own start-up sequence, with labels, for every module shipping an
autostart. FEAT-ASSIST-CHECKLISTS used the F-16C's; this generalises to the others.

## Per aircraft

1. Generate the control index (ticket 01) — requires the module installed.
2. Read `start_sequence_full`, take a **coherent contiguous slice** rather than all 100-odd steps, and
   keep ED's wording for the labels.
3. Write the checklist with `control` texts, run the resolver, verify the values (ticket 04).
4. FR + EN labels — inline
   ([ticket 09](../../FEAT-ASSIST-CHECKLISTS/tickets/09-inline-translations.md)) or as catalog keys
   for the shipped ones. Decide once and stay consistent.

## Which five

**To be established, not assumed**: the modules installed on David's machine that ship a
`Macro_sequencies.lua` with a populated `start_sequence_full`. The F-16C is done. Enumerate them
before starting — the "five" of this ticket's title comes from a passing remark, not a count.

## Careful

- A slice coherent in ED's file can be wrong in isolation. Every checklist wants a pilot's eye before
  it ships, and who reviewed it goes in the file.
- Not every autostart is complete or correct. Where ED's is thin, say so and use the aircraft's
  official manual instead — ticket 06's method.

## Definition of done

- One checklist per aircraft, resolved and verified, each recording its source and its reviewer.
- The shipped catalogue lists them; the documentation says which aircraft have one.
