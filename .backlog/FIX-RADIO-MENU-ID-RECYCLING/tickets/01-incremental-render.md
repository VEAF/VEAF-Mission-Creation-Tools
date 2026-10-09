# 01 — Render the radio menu incrementally

Status: 🔄 in-progress

`RadioMenuBuilder:rebuild()` stops removing the VEAF root.
Every `missionCommands` call of a render goes through the builder, which keys each entry by its audience (all, a coalition, a group), its parent and its label, and keeps what it rendered last time.

## Done when

- An entry rendered again with the same key, callback and parameters reuses the DCS entry: no remove, no add.
- An entry whose callback or parameters changed is removed and added again.
- An entry no longer rendered is removed, children before their parent.
- A second human group joining adds only that group's commands.
- In a paginated menu, an entry already shown keeps its page and a new one goes to the last page.
- Lua tests on the mocks prove each of these.
