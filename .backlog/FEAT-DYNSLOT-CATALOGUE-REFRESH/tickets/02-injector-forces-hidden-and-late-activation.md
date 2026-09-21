# 02 — The injector hides templates itself, not by luck

Status: ✅ done
Type: fix

## The defect

`FIX-TEMPLATE-SLOTS-VISIBLE` made injected templates invisible as pickable slots, and its PRD states
that "the injector already emits `hidden: true` (map only) and `lateActivation: true`". It does not.
`_prepare_injected_group`
([`aircrafts_injector_worker.py:714`](../../../src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py))
sets three fields and only three:

```python
prepared["hiddenOnPlanner"] = True
prepared["hiddenOnMFD"] = True
prepared["password"] = _TEMPLATE_SLOT_PASSWORD
```

`hidden` and `lateActivation` appear in the worker exactly once each, in the validator's list of
known group keys (lines 389 and 395). No code ever writes them. The shipped catalogue carries
`hidden: true` / `lateActivation: true` on all 104 templates, so the output looked right — the data
was doing the work.

Measured on Reaper's extract: **`hidden: false` on all 78 templates, `lateActivation` absent from 77
and `false` on the last one.** Injected as-is, that is 78 template groups drawn on the F10 map of
every mission built from that catalogue. The extraction cannot fix this either: it reports what the
mission holds, and a mission maker configuring templates in the Mission Editor has no reason to tick
"hidden" on each one.

## What to do

Force both in `_prepare_injected_group`, alongside the three existing fields, with a comment saying
why the catalogue is not trusted for them. A template group is never meant to be visible or active:
it exists to be referenced by name by the dynamic-spawn machinery.

## Definition of Done

- `_prepare_injected_group` returns `hidden: True` and `lateActivation: True` whatever the source
  group carried.
- A test feeds it a group with `hidden: false` and no `lateActivation` — Reaper's exact shape — and
  asserts both come out true. It must fail on the current code.
- The source dict is still not mutated (the existing deep-copy contract).
