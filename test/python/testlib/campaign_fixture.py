"""The reference campaign the campaign_manager tests share (FEAT-MULTI-MISSION-CAMPAIGN)."""

import shutil
from pathlib import Path
from typing import Any

from veaf_libs.blank_mission import generate_blank_mission

_REPO = Path(__file__).resolve().parents[3]

#: A small but complete campaign: two airfields, a point zone, a chain of connections.
VALID: dict[str, Any] = {
    "campaign": {
        "name": "Caucasus Front",
        "theatre": "Caucasus",
        "era": "MODERN",
        "missions": 8,
        "objectives": [
            {"capture": ["Senaki"]},
            {"destroy": {"zone": "Gudauta depot", "kind": "logistics"}},
        ],
    },
    "size_classes": {"outpost": {"size": 2}},
    "zones": [
        {"name": "Kobuleti", "at": {"airfield": "Kobuleti"}, "size": "airfield", "side": "blue"},
        {"name": "Senaki", "at": {"airfield": "Senaki-Kolkhi"}, "size": "airfield", "side": "red"},
        {
            "name": "Gudauta depot",
            "at": {"lat": 43.10, "lon": 40.58},
            "size": "outpost",
            "side": "red",
            "kind": "logistics",
            "garrison": ["sa8", "shilka", "T-72B"],
        },
    ],
    "connections": [["Kobuleti", "Senaki"], ["Senaki", "Gudauta depot"]],
}

#: A complete prose file, the shape the Kolkhida prototype was written in.
PROSE: dict[str, Any] = {
    "operation": "Kolkhida",
    "subtitle": "Briefing de situation — campagne",
    "situation": {
        "political": ["Les forces rouges ont franchi l'Inguri.", "Une négociation s'ouvre."],
        "economic": "Le port de Poti ne tourne plus.",
        "enemy_course_of_action": "Tenir Senaki, puis reprendre l'offensive.",
    },
    "mission": "Reprendre Senaki et détruire le dépôt de Khobi.",
    "intent": {"purpose": "Briser l'offensive.", "end_state": "Senaki tenue."},
    "objectives": {"political": ["Rétablir l'autorité du gouvernement."], "military": ["Reprendre Senaki."]},
    "concept": {
        "phases": [{"title": "Phase 1 — la porte de Poti", "text": "Prendre Poti."}],
        "attention": ["Zugdidi n'est pas un objectif."],
    },
    "rules_of_engagement": {"targeting": ["Identification positive avant le tir."]},
    "missions": {1: {"title": "La porte de Poti", "tasks": [{"title": "Prendre Poti", "text": "Sécuriser le port."}]}},
}


def mission_template(folder: Path) -> Path:
    """A minimal mission folder in `folder/template`, as `prepare --theatre Caucasus` lays one down.

    Args:
        folder: The campaign folder.

    Returns:
        The template folder.
    """
    template = folder / "template"
    for relative, content in generate_blank_mission("Caucasus").items():
        path = template / "src" / "mission" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    for shipped in ("warehouses.yaml", "versions.yaml"):
        shutil.copy(_REPO / "src" / "defaults" / "mission-folder" / "src" / shipped, template / "src" / shipped)
    (template / "mission.yaml").write_text(
        "# the mission maker's comment, kept\nmission:\n  name: Campaign mission\nmodules:\n  UNITS: true\n",
        encoding="utf-8",
    )
    (template / "build").mkdir()
    (template / "build" / "old.miz").write_bytes(b"x")
    return template


def _unit(unit_id: int, kind: str, name: str, callsign: str, skill: str = "High", **extra: Any) -> dict[str, Any]:
    return {"unitId": unit_id, "type": kind, "name": name, "skill": skill, "x": 0.0, "y": 0.0, **extra} | (
        {"callsign": {1: 1, 2: 1, 3: 1, "name": callsign}} if callsign else {}
    )


def _group(name: str, units: list[dict[str, Any]], points: list[dict[str, Any]], **extra: Any) -> dict[str, Any]:
    return {"name": name, "units": units, "route": {"points": points}, **extra}


def _point(x: float, y: float, *actions: dict[str, Any], **extra: Any) -> dict[str, Any]:
    tasks = [{"id": "WrappedAction", "params": {"action": action}} for action in actions]
    return {"x": x, "y": y, "task": {"id": "ComboTask", "params": {"tasks": tasks}}, **extra}


#: Where the fixture mission's carrier sails, mission x/y.
CARRIER_XY = (-360000.0, 560000.0)


def built_mission(folder: Path) -> Path:
    """A built `.miz` and its mission folder's `mission.yaml`, as the Kolkhida mission 1 had them.

    Two client flights (one from the carrier, one from Kobuleti), the things that are not flights
    (a dynamic-slot template, a VEAF spawn template), an AWACS, a tanker and the carrier's S-3B, a
    plane guard, the carrier with its tower, TACAN, ICLS and Link 4, a red QRA zone, Kobuleti blue
    with dynamic slots; the ground wind stored blowing TO 90°, so FROM 270°.

    Args:
        folder: The mission folder to write into.

    Returns:
        The `.miz`.
    """
    import zipfile

    import luadata
    from veaf_libs.blank_mission import _serialize
    from veaf_libs.dcs_airdromes import airdrome_id_for_name

    files = generate_blank_mission("Caucasus")
    mission = luadata.unserialize(files["mission"].decode("utf-8").split("=", 1)[1], encoding="utf-8")
    kobuleti = airdrome_id_for_name("Caucasus", "Kobuleti")
    cx, cy = CARRIER_XY
    carrier = _group(
        "CSG-74",
        [_unit(3, "Stennis", "Stennis", "", frequency=127500000, heading=4.712389, x=cx, y=cy)],
        [
            _point(
                cx,
                cy,
                {"id": "ActivateBeacon", "params": {"channel": 74, "modeChannel": "X", "callsign": "CVN"}},
                {"id": "ActivateICLS", "params": {"channel": 1}},
                {"id": "ActivateLink4", "params": {"frequency": 336000000}},
            )
        ],
        x=cx,
        y=cy,
    )
    hornets = _group(
        "Stennis Hornet",
        [_unit(10 + n, "FA-18C_hornet", f"Hornet {n}", f"Uzi1{n}", "Client") for n in range(1, 5)],
        [_point(cx, cy, linkUnit=3)],
        task="CAP",
    )
    vipers = _group(
        "Kobuleti Viper",
        [_unit(20 + n, "F-16C_50", f"Viper {n}", f"Colt1{n}", "Client") for n in range(1, 3)],
        [_point(-317000.0, 636000.0, airdromeId=kobuleti)],
        task="CAS",
    )
    template = _group(
        "F-16C Template",
        [_unit(30, "F-16C_50", "t", "Enfield11", "Client")],
        [_point(0.0, 0.0)],
        dynSpawnTemplate=True,
    )
    spawn = _group("veafSpawn-KC135", [_unit(31, "KC-135", "s", "Shell11")], [_point(0.0, 0.0)], task="Refueling")
    awacs = _group(
        "Overlord", [_unit(40, "E-3A", "a", "Overlord11")], [_point(-360000.0, 540000.0)], task="AWACS", frequency=251
    )
    arco = _group(
        "Arco",
        [_unit(41, "KC-135", "k", "Arco11")],
        [
            _point(-345000.0, 555000.0, {"id": "ActivateBeacon", "params": {"channel": 52, "modeChannel": "X"}}),
            _point(-345000.0, 525000.0),
        ],
        task="Refueling",
        frequency=252,
    )
    texaco = _group(
        "Texaco",
        [_unit(42, "S-3B Tanker", "s3", "Texaco11")],
        [_point(cx, cy + 9000, {"id": "ActivateBeacon", "params": {"channel": 64, "modeChannel": "Y"}})],
        task="Refueling",
        frequency=290,
    )
    pedro = _group("Pedro", [_unit(43, "SH-60B", "h", "Pedro11")], [_point(cx + 500, cy)], task="Transport")
    mission["coalition"]["blue"]["country"] = [
        {
            "id": 2,
            "name": "USA",
            "plane": {"group": [hornets, vipers, template, spawn, awacs, arco, texaco]},
            "helicopter": {"group": [pedro]},
            "ship": {"group": [carrier]},
        }
    ]
    mission["coalition"]["blue"]["bullseye"] = {"x": -291014.0, "y": 617414.0}
    mission["triggers"] = {"zones": [{"name": "QRA Senaki", "x": -281903.0, "y": 648379.0, "radius": 45000}]}
    mission["weather"]["wind"] = {
        "atGround": {"dir": 90, "speed": 8},
        "at2000": {"dir": 90, "speed": 10},
        "at8000": {"dir": 90, "speed": 13},
    }
    mission["weather"]["clouds"] = {"base": 2500, "density": 0, "iprecptns": 0, "thickness": 200, "preset": "Preset3"}
    files["mission"] = _serialize(mission, "mission")
    files["warehouses"] = _serialize(
        {"airports": {kobuleti: {"coalition": "BLUE", "dynamicSpawn": True}}, "warehouses": {}}, "warehouses"
    )
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "mission.yaml").write_text(
        "modules:\n  CSAR: true\n  QRA:\n    enabled: true\n    definitions:\n"
        "      - {name: QRA Senaki, coalition: RED, trigger_zone: QRA Senaki, simple_groups: [g]}\n",
        encoding="utf-8",
    )
    miz = folder / "Campaign_built.miz"
    with zipfile.ZipFile(miz, "w") as archive:
        for name, content in files.items():
            archive.writestr(name, content)
    return miz
