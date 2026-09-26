"""The known limitations of veaf-tools and the DCS behaviours that raise no error.

One data file, ``veaf_libs/data/known-limitations.yaml``, shipped in the executable, read by the MCP
action ``describe_known_limitations`` and rendered into ``docs/agents/dcs-runtime-traps.md``. A trap
written in a prompt or a skill goes stale; here it matches the installed version (FIX-SCRATCH-MISSION-
FINDINGS ticket 13).

Run ``python -m veaf_libs.known_limitations`` to regenerate the page after editing the file.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

import yaml

from veaf_libs.bundled_data import read_bundled_text

KINDS = ("tool", "dcs")
_REQUIRED = ("id", "kind", "area", "title", "symptom", "workaround")

# The page's sections, in order, for the DCS entries it renders; the anchors are the ones the page
# has always exposed.
_DCS_AREAS = {
    "spawning": "## Spawning and timing {#spawning}",
    "air-defence": "## Air defence {#air-defence}",
    "players": "## Players, roles and the map {#players}",
}

GENERATED_BEGIN = "<!-- BEGIN GENERATED from src/python/veaf-tools/veaf_libs/data/known-limitations.yaml -->"
GENERATED_END = "<!-- END GENERATED -->"

_PAGE = Path("docs") / "agents" / "dcs-runtime-traps.md"


def load_known_limitations() -> list[dict[str, Any]]:
    """Read the shipped known-limitations file.

    Returns:
        Every entry, fixed ones included, in file order.
    """
    data = yaml.safe_load(read_bundled_text("veaf_libs", "data", "known-limitations.yaml"))
    return list(data.get("limitations") or [])


def validate_limitations(entries: list[dict[str, Any]]) -> None:
    """Check every entry carries what a reader needs.

    Args:
        entries: The entries to check.

    Raises:
        ValueError: A required field is missing or empty, the kind is unknown, a DCS entry has no
            measurement date or claims a ``fixed_in`` (DCS behaviour is not ours to fix, and marking
            it fixed would hide something still true), or two entries share an id.
    """
    seen: set[str] = set()
    for entry in entries:
        name = entry.get("id", "<no id>")
        for field in _REQUIRED:
            if not str(entry.get(field) or "").strip():
                raise ValueError(f"known limitation {name!r}: missing {field!r}")
        if entry["kind"] not in KINDS:
            raise ValueError(f"known limitation {name!r}: kind must be one of {KINDS}, got {entry['kind']!r}")
        if entry["kind"] == "dcs":
            if not str(entry.get("measured") or "").strip():
                raise ValueError(f"known limitation {name!r}: a dcs entry needs its 'measured' date")
            if entry.get("fixed_in"):
                raise ValueError(f"known limitation {name!r}: a dcs entry cannot have 'fixed_in'")
            if entry["area"] not in _DCS_AREAS:
                raise ValueError(f"known limitation {name!r}: dcs area must be one of {tuple(_DCS_AREAS)}")
        if name in seen:
            raise ValueError(f"known limitation {name!r}: duplicate id")
        seen.add(name)


def _version_tuple(version: str) -> tuple[int, ...] | None:
    """``"6.25.0"`` → ``(6, 25, 0)``; ``None`` when the string does not start with a version."""
    match = re.match(r"^\s*(\d+(?:\.\d+)*)", str(version))
    return tuple(int(part) for part in match.group(1).split(".")) if match else None


def active_limitations(entries: list[dict[str, Any]], version: str, kind: str | None = None) -> list[dict[str, Any]]:
    """Keep the entries that still hold for a given veaf-tools version.

    Args:
        entries: The entries of the file.
        version: The running veaf-tools version. When it cannot be read (a dev install reporting
            ``"unknown"``), nothing is hidden: returning a fixed limitation costs a reader a minute,
            hiding a live one costs them the afternoon.
        kind: Optional ``"tool"`` or ``"dcs"`` filter.

    Returns:
        The DCS entries, always, and the tool entries not fixed in ``version`` or earlier.
    """
    current = _version_tuple(version)
    kept = []
    for entry in entries:
        if kind and entry.get("kind") != kind:
            continue
        fixed = _version_tuple(entry["fixed_in"]) if entry.get("fixed_in") else None
        if fixed is not None and current is not None and current >= fixed:
            continue
        kept.append(entry)
    return kept


def render_markdown(entries: list[dict[str, Any]]) -> str:
    """Render the DCS entries as the sections of ``docs/agents/dcs-runtime-traps.md``.

    Args:
        entries: The entries of the file; tool entries are skipped (the page is about DCS).

    Returns:
        Markdown, one ``##`` section per area and one ``###`` heading per entry.
    """
    out: list[str] = []
    for area, heading in _DCS_AREAS.items():
        in_area = [e for e in entries if e.get("kind") == "dcs" and e.get("area") == area]
        if not in_area:
            continue
        out += [heading, ""]
        for entry in in_area:
            out += [f"### {entry['title']} {{#{entry['id']}}}", ""]
            out += [f"Measured **{entry['measured']}**.", ""]
            out += [entry["symptom"].strip(), ""]
            out += [f"**What to do:** {entry['workaround'].strip()}", ""]
            if entry.get("cost"):
                out += [f"*What it cost:* {entry['cost'].strip()}", ""]
    return "\n".join(out).rstrip() + "\n"


def write_page(page: Path) -> None:
    """Replace the generated block of ``page`` with the current rendering of the file.

    Args:
        page: The Markdown page holding the ``GENERATED_BEGIN`` / ``GENERATED_END`` markers.
    """
    text = page.read_text(encoding="utf-8")
    start = text.index(GENERATED_BEGIN) + len(GENERATED_BEGIN)
    end = text.index(GENERATED_END)
    rendered = render_markdown(load_known_limitations())
    page.write_text(text[:start] + "\n\n" + rendered + "\n" + text[end:], encoding="utf-8", newline="\n")


if __name__ == "__main__":  # pragma: no cover - maintenance entry point
    validate_limitations(load_known_limitations())
    write_page(Path(sys.argv[1]) if len(sys.argv) > 1 else _PAGE)
