# 01 — Channel data model: `priority` + `color`

Status: ✅ done

## Scope

Add `priority: int | None` and `color: str | None` to `Channel` (and carry them
through `add_channel_from_dict` / `parse_channel_lists`). `priority` parsed only
from `channel_lists` entries; `color` parsed from both `channel_lists` entries
(override) and `channels_collection` channel definitions (fallback).

## Acceptance

- A plan entry `{priority: 2, color: green}` yields a `Channel` with
  `priority == 2`, `color == "green"`.
- `color` on a `channels_collection` definition propagates to every plan entry
  referencing it, unless the entry sets its own `color` (override wins).
- `priority` on a `channels_collection` definition is ignored (plan-only).
- Both default to `None` when absent; existing plans keep working unchanged.

## Tests

- `test_channel_lists.py`: priority/color parsing, override precedence, plan-only
  priority.
