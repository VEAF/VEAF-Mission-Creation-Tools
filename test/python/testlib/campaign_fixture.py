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
