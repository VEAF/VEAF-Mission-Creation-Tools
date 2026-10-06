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
