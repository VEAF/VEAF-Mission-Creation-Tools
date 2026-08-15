"""Generate the bundled parking-stand table from DCS runtime parking dumps.

``capture-map --parking`` writes a rich ``airbase_dumps/parking/<Theatre>.json`` (every field DCS's
``Airbase:getParking`` returns, per airbase). That artifact is large — 1.9 MB across three theatres —
and the MCP only needs a slice of it to place an aircraft on a ramp: the stand number, its position,
its altitude, its terminal type, and its distance to the runway. This generator projects the capture
to a **slimmed, bundled** ``veaf_libs/data/parking/<Theatre>.json`` the installed MCP reads at runtime.

Two facts settled in game on 2026-08-15 shape what is kept:

- ``parking`` (the value a mission writes) is the capture's ``Term_Index``; the unit's position is the
  capture's ``vTerminalPos`` (``x`` → mission ``x``, ``z`` → mission ``y``, ``y`` → altitude).
- ``parking_id`` is **not** in the capture (``Term_Index_0`` is -1 throughout) and is **not
  load-bearing**: a slot placed at the exact position with ``parking_id`` = ``parking`` parks
  correctly. So it is not stored — the MCP sets ``parking_id`` = ``parking``.

Runtime-dependent, so the committed artifact is **not** CI-guarded. Run via
``veaf-build update-dcs-data --parking``.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

# Committed slimmed artifact the MCP reads at runtime (one file per captured theatre).
DEFAULT_OUTPUT_DIR = Path(__file__).parent.parent.parent / "src/python/veaf-tools/veaf_libs/data/parking"

# Committed rich runtime dumps, one parking/<Theatre>.json per captured theatre.
DUMPS_DIR = Path(__file__).parent / "airbase_dumps" / "parking"


def slim_stand(stand: dict[str, Any]) -> dict[str, Any]:
    """Project one captured stand to the fields the MCP needs to place an aircraft.

    Args:
        stand: A raw capture stand (``Term_Index``, ``vTerminalPos.*``, ``Term_Type``, ``fDistToRW``).

    Returns:
        ``{"p": parking, "x": mission_x, "y": mission_y, "alt": altitude, "t": term_type, "d": dist_rw}``.
    """
    return {
        "p": str(stand["Term_Index"]),
        "x": float(stand["vTerminalPos.x"]),
        "y": float(stand["vTerminalPos.z"]),  # mission y is the runtime z
        "alt": float(stand["vTerminalPos.y"]),  # runtime y is the altitude
        "t": str(stand["Term_Type"]),
        "d": float(stand["fDistToRW"]),
    }


def slim_dump(doc: dict[str, Any]) -> dict[str, Any]:
    """Slim a whole captured theatre dump to ``{theatre, by_airbase: {id: [stand, ...]}}``."""
    by_airbase = {
        str(airbase_id): [slim_stand(s) for s in stands]
        for airbase_id, stands in (doc.get("parking_by_airbase") or {}).items()
    }
    return {"theatre": doc.get("theatre"), "by_airbase": by_airbase}


def generate(dumps_dir: Path = DUMPS_DIR, output_dir: Path | None = None) -> int:
    """Slim every committed parking dump into the bundled data directory.

    Args:
        dumps_dir: Directory holding the rich ``parking/<Theatre>.json`` captures.
        output_dir: Destination for the slimmed files. Defaults to :data:`DEFAULT_OUTPUT_DIR`.

    Returns:
        The number of theatres written.
    """
    if output_dir is None:
        output_dir = DEFAULT_OUTPUT_DIR
    if not dumps_dir.is_dir():
        return 0
    output_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    for dump in sorted(dumps_dir.glob("*.json")):
        doc = json.loads(dump.read_text(encoding="utf-8"))
        slim = slim_dump(doc)
        out = output_dir / f"{slim['theatre'] or dump.stem}.json"
        out.write_text(json.dumps(slim, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        written += 1
    return written


if __name__ == "__main__":
    count = generate()
    print(f"Wrote slimmed parking data for {count} theatre(s) to {DEFAULT_OUTPUT_DIR}")
