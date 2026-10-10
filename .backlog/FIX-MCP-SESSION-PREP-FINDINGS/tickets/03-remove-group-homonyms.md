# 03 — `remove_group` refuses an ambiguous name and takes `group_id`

Status: 🔄 in-progress

`remove_group` located the first group of the name, then filtered the container by name: every homonym went, one was reported.

- Several groups of the name and no `group_id`: refused, listing each `groupId` with its coalition and category; nothing written.
- `group_id` given: only that group goes, by identity, its homonym stays; a `group_id` not carrying the name is refused.
- Needed even with ticket 02: a mission written before it may already hold homonyms, and this is how they are cleaned.
- Doc: the `remove_group` section of the MCP page (FR + EN) and the action's schema.
