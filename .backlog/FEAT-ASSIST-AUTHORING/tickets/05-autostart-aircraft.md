# 05 — the five aircraft that ship an autostart

**Status:** ⏸ paused — David's call on 2026-08-03: no further checklist for now.

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

## Which five — established: eleven, not five

Counted on 2026-08-03, modules installed here shipping a populated `start_sequence_full`: A-10C II,
AH-64D, C-130J, CH-47F, F-16C, Ka-50 III, Mi-24P, Mi-8MTV2, TF-51D, UH-1H, Yak-52 — plus the F/A-18C
installed the same day. The "five" was a passing remark, as suspected.

**What a checklist costs, measured.** Feeding each autostart's own messages to the resolver:

| Aircraft | Autostart steps | Resolved outright |
|---|---|---|
| F-16C | 115 | 60 |
| F/A-18C | 138 | 39 |
| A-10C II | 89 | ~4 |
| AH-64D | 86 | 2 |

The resolver finds the right control nearly every time; what it lacks is the **value** of the
positions, and that tracks the binding coverage exactly (F-16C 104 controls of 285, AH-64D 7 of 478).
So: near-free for ED's recent jets, one cockpit session per aircraft for the rest — which is what
`explore-cockpit` (ticket 08) exists for.

**Paused deliberately.** Eleven checklists nobody reviews are eleven liabilities: this ticket already
says each one wants a pilot's eye and records its reviewer. Reopen it aircraft by aircraft, when
someone actually wants one.

## Careful

- A slice coherent in ED's file can be wrong in isolation. Every checklist wants a pilot's eye before
  it ships, and who reviewed it goes in the file.
- Not every autostart is complete or correct. Where ED's is thin, say so and use the aircraft's
  official manual instead — ticket 06's method.

## Definition of done

- One checklist per aircraft, resolved and verified, each recording its source and its reviewer.
- The shipped catalogue lists them; the documentation says which aircraft have one.
