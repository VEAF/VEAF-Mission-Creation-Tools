# 11 — No dynamic-slot templates for a side with no slot base

Status: ✅ done

The build injected red's dynamic-slot templates on a mission where red has no base offering slots. The templates of a side whose bases offer none are left out; nothing changes when the source warehouses cannot be read.

Done when: covered by a test, and the documentation says it.

## Result

`dynamic_slot_sides`, `filter_by_sides`, `side_filtered_catalogue`; `pipeline.dynamic_slot_templates.all_sides` keeps them. Tests: `test_dynamic_templates_by_side.py`, and an end-to-end build (`test_a_side_with_no_slot_base_gets_no_dynamic_slot_template`) shown to fail without the wiring.
