# 04 — A QRA draw keeps its count when it exceeds the list

Status: ✅ done

Issue: [#1308](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1308).

Since `32ca2051` (2026-10-08), `pickDistinctGroups` draws without replacement and stops when the list is empty: "4 of [A, B]" sends 2 groups, where v5 sent 4 (each drawn group was cloned under a new name).
The comment of `pickDistinctGroups` and the CHANGELOG line that justify the change say a group drawn twice came out once; it came out twice.

- Keep the draw without replacement while the list lasts: "2 of [A, B]" is still A and B, never A twice.
- When the count exceeds the list, start a new round over the whole list for the remainder: "4 of [A, B]" sends 4 groups, each group at most twice.
- Fix the comment of `pickDistinctGroups`.
- Add a CHANGELOG entry that corrects the earlier one, under Migration: a tier whose count exceeds its list sends its full count again.

Tests: with a real random draw (not the mocks' constant 0), many draws — "2 of [A, B]" always gives A and B; "4 of [A, B]" always gives 4 groups, 2 of each; "3 of [A, B, C, D]" gives 3 distinct groups.

Done when: the tests pass, and `doc/mission-maker/scripts/` (the QRA page, FR and EN) says what a count larger than the list does.
