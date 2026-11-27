"""What one MCP response may put in the client's context (MCP-CONTEXT-BUDGET).

A tool result stays in the model's context to the end of the session. `mcp` serialises a returned
object with `indent=2`, a returned list as one content block per item, plus a `structuredContent`
copy: measured on 2026-11-25, the limitations listing lost 30 % to indentation and `list_catalog` came
as 75 blocks. A local model at 65 000 tokens filled its context reading the skeleton of one mission.
"""

import json
from typing import Any

#: The longest response a tool sends, in characters: about 4 000 tokens of JSON at the 2 characters a token
#: measured on a local model. 16 000 let one cut answer (an unfiltered describe_units) add 9 500 tokens and
#: overflow a 65 536-token context right after the build (2026-11-25). Below 8 000 the guide's default
#: answer (7 515) and its combat-zone section (7 549) would be cut themselves.
MAX_RESPONSE_CHARS = 8_000

#: The longest action schema a tool sends: a schema is read whole or not at all, and the largest
#: (`build_mission_briefing`) is 11 029 characters.
MAX_SCHEMA_CHARS = 16_000

#: What a cut response says when its action gives no way of its own to read the rest.
_GENERIC_HINT = "Narrow the request (a filter, a section, an id, a slice) to read the rest."


def to_text(result: Any) -> str:
    """Serialise a tool result as the one text block the client reads.

    Args:
        result: What the action returned.

    Returns:
        A string unchanged; anything else as compact JSON, accents kept.
    """
    if isinstance(result, str):
        return result
    return json.dumps(result, ensure_ascii=False, separators=(",", ":"), default=str)


def capped(text: str, hint: str | None = None, limit: int = MAX_RESPONSE_CHARS) -> str:
    """Return `text`, or in its place its start and how to read the rest when it is over `limit`.

    Args:
        text: The serialised response.
        hint: How to read the rest with this action, for the model.
        limit: The longest response, in characters.

    Returns:
        `text` when it fits; otherwise a compact JSON object `{truncated, total_chars, shown_chars,
        how_to_read_the_rest, head}` no longer than `limit`, `head` being the start of `text`.
    """
    if len(text) <= limit:
        return text
    envelope = {
        "truncated": True,
        "total_chars": len(text),
        "shown_chars": 0,
        "how_to_read_the_rest": hint or _GENERIC_HINT,
        "head": "",
    }
    # JSON escapes can make the head longer than its characters: shrink until the whole fits.
    shown = limit - len(to_text(envelope)) - 32
    while shown > 0:
        envelope["shown_chars"] = shown
        envelope["head"] = text[:shown]
        result = to_text(envelope)
        if len(result) <= limit:
            return result
        shown -= len(result) - limit + 16
    envelope["head"] = ""
    envelope["shown_chars"] = 0
    return to_text(envelope)
