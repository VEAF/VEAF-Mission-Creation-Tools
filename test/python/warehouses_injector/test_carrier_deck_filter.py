"""FIX-OPEN-TRAINING-PROMPT-FINDINGS ticket 03 — a carrier deck offers only what can use it.

The default stock of a ship used to be every dynamic template of its side: on GermanyCW-v6 the
Stennis was offered 51 types, the B-52H included. The filter reads DCS's own declaration: an
aircraft's ``TakeOffRWCategories`` and ``LandRWCategories``, matched against the ship's attributes.
"""

from __future__ import annotations

from pathlib import Path

from mission_tools.miz_tools import DcsMission
from warehouses_injector import apply_warehouses

_STENNIS = 10
_TARAWA = 11
_PERRY = 12

_TYPES = ("F-14B", "FA-18C_hornet", "AV8BNA", "Su-33", "B-52H", "F-16C_50", "UH-1H")


def _mission(stale: dict | None = None) -> DcsMission:
    """One blue side with a template per type in `_TYPES`, a CVN, an LHA and a frigate."""
    planes = [
        {"groupId": 100 + i, "name": f"T {t}", "dynSpawnTemplate": True, "units": [{"type": t}]}
        for i, t in enumerate(_TYPES)
        if t != "UH-1H"
    ]
    helis = [{"groupId": 200, "name": "T UH-1H", "dynSpawnTemplate": True, "units": [{"type": "UH-1H"}]}]
    ships = [
        {"name": name, "units": [{"unitId": uid, "name": name, "type": unit_type}]}
        for uid, name, unit_type in (
            (_STENNIS, "CVN-74", "Stennis"),
            (_TARAWA, "LHA-1", "LHA_Tarawa"),
            (_PERRY, "FFG-7", "PERRY"),
        )
    ]
    content = {
        "coalition": {
            "blue": {
                "country": [
                    {
                        "name": "CJTF Blue",
                        "id": 80,
                        "plane": {"group": planes},
                        "helicopter": {"group": helis},
                        "ship": {"group": ships},
                    }
                ]
            }
        }
    }
    warehouses = {uid: {"coalition": "BLUE", "aircrafts": {}} for uid in (_STENNIS, _TARAWA, _PERRY)}
    if stale:
        warehouses[_STENNIS]["aircrafts"] = stale
    return DcsMission(
        file_path=Path("dummy.miz"),
        mission_content=content,
        warehouses_content={"airports": {}, "warehouses": warehouses},
        theatre_content="Caucasus",
    )


def _offered(mission: DcsMission, unit_id: int) -> set[str]:
    stock = (mission.warehouses_content or {})["warehouses"][unit_id].get("aircrafts") or {}
    return {t for sub in stock.values() for t in sub}


class TestDefaultStock:
    def test_a_catapult_carrier_takes_its_carrier_aircraft_and_the_helicopters(self) -> None:
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert _offered(mission, _STENNIS) == {"F-14B", "FA-18C_hornet", "AV8BNA", "UH-1H"}

    def test_an_lha_takes_the_harrier_and_the_helicopters_not_the_catapult_jets(self) -> None:
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert _offered(mission, _TARAWA) == {"AV8BNA", "UH-1H"}

    def test_a_frigate_takes_the_helicopter(self) -> None:
        mission = _mission()
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert _offered(mission, _PERRY) == {"UH-1H"}

    def test_what_an_earlier_build_stocked_off_deck_is_removed(self) -> None:
        stale = {"planes": {"B-52H": {"unlimited": True}, "F-14B": {"unlimited": True}}}
        mission = _mission(stale)
        apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert "B-52H" not in _offered(mission, _STENNIS)
        assert "F-14B" in _offered(mission, _STENNIS)


class TestExplicitList:
    def test_an_explicit_list_is_obeyed_as_written(self) -> None:
        mission = _mission()
        config = {"blue": {"defaults": {}, "ships": {"CVN-74": {"aircrafts": {"B-52H": {"amount": 2}}}}}}
        apply_warehouses(mission, config)
        assert _offered(mission, _STENNIS) == {"B-52H"}
