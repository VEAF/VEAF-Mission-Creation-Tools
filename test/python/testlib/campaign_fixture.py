"""The reference campaign the campaign_manager tests share (FEAT-MULTI-MISSION-CAMPAIGN)."""

from typing import Any

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
