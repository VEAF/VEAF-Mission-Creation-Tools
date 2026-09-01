# 02 — Two tests that read the clock instead of the number

Status: ✅ done

Type: fix · Files: `test/python/mission_builder/test_convert_report_rendering.py`,
`test/python/mission_builder/test_convert_other_delay_sync.py`

## The defect

`test_the_counter_and_the_items_agree` asserted:

```python
self.assertIn("3", markdown.split("\n---")[0], "the summary counts review items and warnings")
```

The report's first divider comes straight after the title and the timestamp, so that slice is:

```
# Rapport de conversion VEAF Mission v5 → v6

*Généré le 2026-09-01 10:32 par veaf-tools convert-v5 vtest*
```

The counter — `- ⚠️ 3 éléments nécessitent une action manuelle` — sits in the **next** slice and was
never examined. What the assertion matched was the `3` of `10:32`. The test therefore passed at
10:32 and failed at 10:27, in either locale; CI drew a lucky minute and the workstation did not.

Its comment read *"Pinning both together so a future edit cannot restore the state where one moves
without the other."* It pinned neither: the counter could be set to `len(items) - 1` and the test
stayed green.

`test_the_report_names_every_delay_written` had the same shape — `assertIn("12", markdown)` over the
whole document, which also matches twelve minutes past any hour.

Both came from PR #857, two days old.

## What was done

- Both assertions now read the **one line** carrying the number: the summary line for the counter,
  the line naming the script for the delay. Locale-independent, and independent of the clock.
- Added `test_the_counter_follows_the_number_of_items`, which drives totals of 1 and 5: a test that
  only ever sees one total cannot tell a real count from a constant.

## Proof they can fail

- Counter rendered as `len(manual_items) - 1` → both counter tests red (the old assertion stayed
  green under the same sabotage).
- Delay reported as `0` instead of the value written → the delay test red, along with three
  neighbours.

## Note

`test_custom_script_load_delay.py:170-171` has the same `assertIn("3", …)` shape but reads
`spec.comment`, which carries no timestamp. Left alone: no defect, and touching it would be
speculative.
