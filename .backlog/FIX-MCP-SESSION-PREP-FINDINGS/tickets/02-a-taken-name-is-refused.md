# 02 — A group or unit name already in the mission is refused

Status: ✅ done

`mission_tools.group_insertion.add_group`, which every MCP action creating a group goes through, appended whatever it was given — documented as "not deduplicated, like two clicks in the Mission Editor", which is wrong twice: the editor renames a copy, and DCS resolves either of two homonyms by name.

- The insertion refuses a group name, or a unit name, the mission already holds (any coalition, any category), naming what holds it; nothing is written.
- Tests: the two "calling twice creates two groups" tests become refusals; a unit-name clash; a mission whose groups read back as a dict table; `add_air_group` twice with one name, the session's case.
- Doc: the `add_group` bullet of the MCP page (FR + EN), the `add_group` action description and module docstring.
