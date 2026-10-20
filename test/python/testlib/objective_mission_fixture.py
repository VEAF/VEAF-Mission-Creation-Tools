"""A built one-shot objective mission, for the mission briefing's tests (FEAT-MCP-MISSION-BRIEFING).

The campaign fixture's built mission (`campaign_fixture.built_mission`: flights, carrier, support, QRA,
weather, a flight plan over POTI and KHOBI), plus what an objective mission adds: a combat zone at
KHOBI with an SA-8 group and a static depot in it, an SA-6 site outside it, a red unit near the zone
that is not one of its members, and the presets the build injected into the Kobuleti flight.
"""

from __future__ import annotations

import itertools
import zipfile
from pathlib import Path
from typing import Any

import luadata
from campaign_fixture import built_mission
from veaf_libs.blank_mission import _serialize

#: The objective's combat zone, mission x/y and radius.
KHOBI_ZONE = ("Khobi", -274838.0, 634185.0, 2500.0)

#: Where the SA-6 site stands, outside the zone.
SA6_XY = (-284000.0, 646000.0)

#: The channels the build injected into the Kobuleti flight's first radio.
UHF_CHANNELS = {1: (390.5, "Ninja"), 2: (282.2, "Magic"), 3: (290.5, "Arco-1/BM/64Y")}


_IDS = itertools.count(500)


def _unit(name: str, kind: str, x: float, y: float, **extra: Any) -> dict[str, Any]:
    return {"name": name, "type": kind, "x": x, "y": y, "unitId": next(_IDS), **extra}


def objective_mission(folder: Path) -> Path:
    """Write the built objective mission and its `mission.yaml` into a mission folder.

    Args:
        folder: The mission folder; the `.miz` goes into its `build/`.

    Returns:
        The `.miz`.
    """
    built = built_mission(folder / "build")
    (folder / "build" / "mission.yaml").replace(folder / "mission.yaml")
    with zipfile.ZipFile(built) as archive:
        files = {name: archive.read(name) for name in archive.namelist()}
    mission = luadata.unserialize(files["mission"].decode("utf-8").split("=", 1)[1], encoding="utf-8")

    name, zx, zy, radius = KHOBI_ZONE
    mission["triggers"]["zones"].append({"name": name, "x": zx, "y": zy, "radius": radius, "zoneId": 2})
    red = {
        "id": 0,
        "name": "Russia",
        "vehicle": {
            "group": [
                {"name": "Khobi-SA8", "units": [_unit("Khobi-SA8-1", "Osa 9A33 ln", zx + 300, zy + 200)]},
                {"name": "SA-6 Site", "units": [_unit("SA-6 Site-1", "Kub 1S91 str", *SA6_XY)]},
                {"name": "Patrol", "units": [_unit("Patrol-1", "BTR-80", zx - 400, zy)]},
            ]
        },
        "static": {
            "group": [{"name": "Depot", "units": [_unit("Khobi Dépôt de munitions", "Shelter", zx - 200, zy - 300)]}]
        },
    }
    mission["coalition"]["red"]["country"] = [red]
    for group in mission["coalition"]["blue"]["country"][0]["plane"]["group"]:
        if group["name"] == "Kobuleti Viper":
            first = group["units"][0]
            first["Radio"] = {
                1: {
                    "channels": {n: freq for n, (freq, _) in UHF_CHANNELS.items()},
                    "channelsNames": {n: title for n, (_, title) in UHF_CHANNELS.items()},
                }
            }
    files["mission"] = _serialize(mission, "mission")
    miz = folder / "build" / "VEAF_Caucasus_Khobi.miz"
    with zipfile.ZipFile(miz, "w") as archive:
        for member, content in files.items():
            archive.writestr(member, content)
    built.unlink()
    return miz
