"""A ground group that drives somewhere starts on the road, at a convoy's speed.

FIX-OPEN-TRAINING-FALKLANDS-FINDINGS ticket 04: `create_combat_zone` wrote a convoy's first point `Off Road`
and every leg at 5.6 m/s. Over the 126 vehicle groups of 14 editor-built missions whose route has an
`On Road` leg (measured 2026-10-13), the first point is `On Road` in 85 and the legs' speed has a median of
16.4 m/s.
"""

import pytest
from veaf_mission_mcp import add_group as module

_A = {"x": 0.0, "y": 0.0}
_B = {"x": 1000.0, "y": 0.0}
_C = {"x": 2000.0, "y": 0.0}


def _ground(route: list[dict[str, float]], **extra: object) -> list[dict]:
    group = module._build_group(
        name="convoy", position=_A, units=[{"type": "Ural-375"}], route=route, patrol=False, **extra
    )
    return group["route"]["points"]


class TestAGroundRouteIsAConvoyRoute:
    def test_a_route_with_legs_starts_on_the_road(self) -> None:
        assert [p["action"] for p in _ground([_A, _B, _C])] == ["On Road", "On Road", "On Road"]

    def test_a_single_stationary_point_stays_off_road(self) -> None:
        assert [p["action"] for p in _ground([_A])] == ["Off Road"]

    def test_the_legs_run_at_the_measured_convoy_speed(self) -> None:
        points = _ground([_A, _B, _C])
        assert [p["speed"] for p in points[1:]] == [module._ROAD_SPEED_MPS] * 2
        assert module._ROAD_SPEED_MPS == pytest.approx(16.4)

    def test_the_start_point_keeps_the_start_speed(self) -> None:
        assert _ground([_A, _B])[0]["speed"] == module._DEFAULT_SPEED_MPS

    def test_a_speed_given_on_a_point_wins(self) -> None:
        points = _ground([_A, {**_B, "speed": 8.0}, _C])
        assert [p["speed"] for p in points[1:]] == [8.0, module._ROAD_SPEED_MPS]


class TestOtherRoutesAreUntouched:
    def test_a_ship_keeps_its_turning_points_and_its_speed(self) -> None:
        group = module._build_ship_group(name="boat", position=_A, units=[{"type": "Dry-cargo ship-1"}], route=[_A, _B])
        points = group["route"]["points"]
        assert [p["action"] for p in points] == ["Turning Point", "Turning Point"]
        assert [p["speed"] for p in points] == [module._DEFAULT_SPEED_MPS] * 2
