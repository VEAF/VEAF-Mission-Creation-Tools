# 04 — context around a search hit, without overriding the filters

Status: ✅ done

Part of [FEAT-VEAF-LOGS-READABILITY](../PRD.md).

`evaluate()` classifies each entry from its categories, then lets every text filter narrow the
result, then widens it back for the categories left in ◐. The search itself only ever narrows.

Give it the same two-level setting the categories already have, so there is one model to learn and
not two:

- `FilterSet.search_context_lines` — the common value, a spinbox in the side panel under the one
  for the categories, which gets relabelled so the two are told apart
- `TextFilter.context_lines: int | None` — the override for one criterion, a small `±` spinbox in
  the search bar, empty meaning "the common value", exactly like `CategoryRow.span`. It travels
  with the chip when the criterion is added, and shows in `describe()`

Several criteria active: the **widest** span wins, the rule `_classify` already applies when two
categories disagree. An inverted criterion (`≠`) has no hits to surround and does not count.

The part to get right is that context must not undo a filter. Snapshot what the categories allow
**before** the text filters run; the search context may only pull entries back from that snapshot.
A line hidden by level, source or noise family stays hidden however close it is to a hit.

The category context then runs after, on the widened set, so the two compose:
`test_le_contexte_se_combine_avec_la_recherche` must still pass unchanged.

Default 0 — no context until asked for, per David 2026-09-01 — so no existing search changes its
result and no existing profile changes meaning.

Done when a search with ±2 shows the two lines on each side of each hit, and turning a level to ✕
removes those of its lines from the context too.
