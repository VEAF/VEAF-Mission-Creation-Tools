# 01 — Compact JSON in one block, and a 16 000-character ceiling on every response

Status: 🔄 in-progress

`mcp` serialises a returned object with `indent=2` and a returned list as one content block per item, plus a `structuredContent` copy: the limitations listing lost 30 % to indentation, and `list_catalog` came as 75 blocks and a second copy.

- `run_action`, `describe_action` and `list_catalog` answer one text block of compact JSON, no structured copy.
- A response over 16 000 characters is replaced by its start, its total size and how to read the rest, worded per action.
- An explicit request for everything (`section: all`, `part: all`) is not cut: that is the large-context client's own choice.
