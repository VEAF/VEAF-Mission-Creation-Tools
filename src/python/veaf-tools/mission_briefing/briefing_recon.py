"""Recon photos of the objectives, read from a folder of JPEG and their JSON sidecars (FEAT-OBJECTIVE-MISSION-V2 04).

"Marteau du Golan" showed a photo of each target taken in DCS along the attack axis, its heading
written on it: a pilot recognised the target before seeing it. Taking them needs DCS (another lot); the
briefing reads what that lot leaves, one ``<stem>.jpg`` and one ``<stem>.json`` per photo::

    {"zone": "SA6Sasa", "title": "Batterie SA-6", "heading": 95, "pitch": -12,
     "x": -191850.0, "y": 5120.0, "altitude_m": 850, "order": 1}

``zone`` and ``title`` are required; the rest is printed when given. The interface is documented in
`doc/developer/mission-editing-mcp.md` (``build_mission_briefing``).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from veaf_libs.coordinates import to_dms, xy_to_latlon
from veaf_libs.i18n import t
from veaf_libs.terrain_elevation import metres_to_feet

from mission_briefing.models import ReconPhoto

#: Where the photos are by default, in the mission folder.
RECON_FOLDER = Path("docs") / "recon"

_IMAGE_SUFFIXES = (".jpg", ".jpeg")


def _number(raw: dict[str, Any], key: str) -> float | None:
    value = raw.get(key)
    return float(value) if isinstance(value, int | float) and not isinstance(value, bool) else None


def load_recon(folder: Path, zones: list[str]) -> tuple[dict[str, list[ReconPhoto]], list[str]]:
    """Read the recon photos of a folder, by objective zone.

    Args:
        folder: The folder of photos and sidecars; nothing is read when it does not exist.
        zones: The briefing's objective zones, as ``objectives[].zone`` names them.

    Returns:
        The photos by zone (as ``zones`` spells it), sorted by ``order`` then file name, and one warning
        per photo skipped.
    """
    by_zone: dict[str, list[ReconPhoto]] = {}
    warnings: list[str] = []
    if not folder.is_dir():
        return by_zone, warnings
    known = {zone.lower(): zone for zone in zones}
    images = {p.stem: p for p in folder.iterdir() if p.suffix.lower() in _IMAGE_SUFFIXES}
    sidecars = {p.stem: p for p in folder.iterdir() if p.suffix.lower() == ".json"}
    for stem in sorted(set(sidecars) - set(images)):
        warnings.append(f"Recon {sidecars[stem].name}: no {stem}.jpg beside it; skipped.")
    for stem, image in sorted(images.items()):
        sidecar = sidecars.get(stem)
        if sidecar is None:
            warnings.append(f"Recon {image.name}: no {stem}.json sidecar; skipped.")
            continue
        try:
            raw = json.loads(sidecar.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            warnings.append(f"Recon {sidecar.name}: unreadable ({error}); skipped.")
            continue
        if not isinstance(raw, dict) or not raw.get("zone") or not raw.get("title"):
            warnings.append(f"Recon {sidecar.name}: 'zone' and 'title' are required; skipped.")
            continue
        zone = known.get(str(raw["zone"]).lower())
        if zone is None:
            warnings.append(f"Recon {image.name}: zone {raw['zone']!r} is no objective of the briefing; skipped.")
            continue
        by_zone.setdefault(zone, []).append(
            ReconPhoto(
                image=image,
                zone=zone,
                title=str(raw["title"]),
                heading=_number(raw, "heading"),
                pitch=_number(raw, "pitch"),
                x=_number(raw, "x"),
                y=_number(raw, "y"),
                altitude_m=_number(raw, "altitude_m"),
                order=_number(raw, "order") or 0.0,
            )
        )
    for photos in by_zone.values():
        photos.sort(key=lambda photo: (photo.order, photo.image.name))
    return by_zone, warnings


def caption(theatre: str, photo: ReconPhoto) -> str:
    """``Batterie SA-6 — cap 095°, piqué -12°, depuis N33°… E036°…, 2 789 ft``, with what the sidecar gives."""
    parts = []
    if photo.heading is not None:
        parts.append(t("mission_briefing.recon.heading", heading=f"{round(photo.heading) % 360:03d}"))
    if photo.pitch is not None:
        parts.append(t("mission_briefing.recon.pitch", pitch=f"{photo.pitch:+.0f}"))
    if photo.x is not None and photo.y is not None:
        parts.append(t("mission_briefing.recon.from", position=to_dms(*xy_to_latlon(theatre, photo.x, photo.y))))
    if photo.altitude_m is not None:
        parts.append(f"{metres_to_feet(photo.altitude_m):,.0f} ft".replace(",", " "))
    return f"{photo.title} — {', '.join(parts)}" if parts else photo.title
