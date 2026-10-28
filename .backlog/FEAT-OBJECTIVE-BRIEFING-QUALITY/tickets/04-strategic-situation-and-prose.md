# 04 — Strategic situation page, prose accepted

Status: ✅ done

A new optional `strategic_situation` text makes its own page after the cover. A text passed as one string is split on blank lines into paragraphs, in every heading; `mission_bullets` passed as a string is prose, without the dashes.

Done when: the behaviour is covered by a test, and the action's documentation says it.

## Result

`strategic_situation` page after the cover; `_lines` splits one string on blank lines; `mission_prose` drops the dashes. Tests: `TestProse`, `test_a_text_given_as_one_string_is_split_into_paragraphs_and_a_mission_string_is_prose`.
