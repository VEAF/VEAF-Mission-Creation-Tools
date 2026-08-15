"""`set_group_properties` — move, rename and reconfigure a group that already exists.

Ticket 03 of `FEAT-MCP-MUTATION-ACTIONS`. **Move** is the one with a real design question, and it is
not "set x and y":

- A group is not a point. It is units in a formation, plus possibly a route, and moving it has to
  translate **every unit and every waypoint by the same delta** — otherwise the formation shears or
  the route detaches from the units it belongs to. The shear case has its own test, and it fails on
  any implementation that moves only the units.
- The delta comes from the **geodesic** offset `FEAT-GEO-PLACEMENT` already ships, not from adding
  metres to `x`: a DCS theatre is the real world projected, so a bearing and a distance are a
  lat/lon problem, and ADR 0015 owns that conversion.

**Frequency** is gated on the airframe's `HumanRadio` bound rather than written blind, because
`FIX-PRIMARY-FREQ-HUMANRADIO` established that the Mission Editor *refuses to save* a mission whose
primary frequency falls outside it — a failure that surfaces long after the write, in the editor,
with nothing pointing back here.

What this action cannot do, measured rather than forgotten: **check the destination's surface**.
There is no terrain data on the Python side — `land.getSurfaceType` is a runtime API, and only its
schema ships here — which is exactly why `FEAT-SCENERY-AWARE-SPAWN` solved that problem at runtime.
So a move warns that it could not look, instead of validating and lying.
"""

import zipfile
from pathlib import Path

import pytest
from mission_tools.miz_tools import read_miz
from veaf_libs import coordinates
from veaf_mission_mcp.set_group_properties import set_group_properties

#: A mission whose groups carry what a move must keep consistent: several units in formation and a
#: route, an aircraft group with a frequency, and a group named after a trigger zone.
_MISSION_LUA = b"""
mission = {
  ["coalition"] = {
    ["blue"] = {
      ["country"] = {
        [1] = {
          ["name"] = "USA",
          ["plane"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Colt 1-1",
                ["groupId"] = 10,
                ["frequency"] = 251,
                ["modulation"] = 0,
                ["lateActivation"] = false,
                ["hidden"] = false,
                ["uncontrolled"] = false,
                ["x"] = -300000.0,
                ["y"] = 600000.0,
                ["units"] = {
                  [1] = {
                    ["name"] = "Colt 1-1-1",
                    ["type"] = "FA-18C_hornet",
                    ["x"] = -300000.0,
                    ["y"] = 600000.0,
                  },
                  [2] = {
                    ["name"] = "Colt 1-1-2",
                    ["type"] = "FA-18C_hornet",
                    ["x"] = -299800.0,
                    ["y"] = 600150.0,
                  },
                },
                ["route"] = {
                  ["points"] = {
                    [1] = {
                      ["x"] = -300000.0,
                      ["y"] = 600000.0,
                      ["alt"] = 2000,
                      ["ETA_locked"] = true,
                    },
                    [2] = {
                      ["x"] = -290000.0,
                      ["y"] = 610000.0,
                      ["alt"] = 6000,
                      ["ETA_locked"] = false,
                    },
                  },
                },
              },
            },
          },
          ["vehicle"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Ground Convoy",
                ["groupId"] = 20,
                ["x"] = -320000.0,
                ["y"] = 620000.0,
                ["units"] = {
                  [1] = {
                    ["name"] = "Convoy-1",
                    ["type"] = "M-1 Abrams",
                    ["x"] = -320000.0,
                    ["y"] = 620000.0,
                  },
                },
              },
            },
          },
        },
      },
    },
  },
  ["triggers"] = {
    ["zones"] = {
      [1] = {
        ["name"] = "czBatumi",
        ["x"] = -356734.0,
        ["y"] = 617270.0,
        ["radius"] = 4572,
        ["zoneId"] = 670,
      },
    },
  },
}
"""


@pytest.fixture
def miz(tmp_path: Path) -> Path:
    """A real `.miz` on Caucasus, so the geodesic projection is available."""
    path = tmp_path / "mission.miz"
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("mission", _MISSION_LUA)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return path


def _values(container: object) -> list:
    """Return a DCS table's entries whether it came back as a 1-based dict or a list."""
    if isinstance(container, dict):
        return list(container.values())
    return list(container) if isinstance(container, list) else []


def _group(miz_path: Path, group_name: str) -> dict:
    """Read one group straight out of the written mission."""
    content = read_miz(miz_path).mission_content
    assert content is not None
    for coalition in _values(content.get("coalition")):
        for country in _values(coalition.get("country")):
            for category in ("plane", "helicopter", "vehicle", "ship", "static"):
                for group in _values((country.get(category) or {}).get("group")):
                    if group.get("name") == group_name:
                        return group
    raise AssertionError(f"group not found in written mission: {group_name}")


def _positions(miz_path: Path, group_name: str) -> tuple[list[tuple[float, float]], list[tuple[float, float]]]:
    """Return ``(unit positions, waypoint positions)`` of a group as written."""
    group = _group(miz_path, group_name)
    units = [(unit["x"], unit["y"]) for unit in _values(group.get("units"))]
    points = [(point["x"], point["y"]) for point in _values((group.get("route") or {}).get("points"))]
    return units, points


class TestMoveKeepsTheGroupTogether:
    """The formation and the route travel with the units, by the same delta."""

    def test_every_unit_moves_by_the_same_delta(self, miz: Path) -> None:
        before, _ = _positions(miz, "Colt 1-1")
        set_group_properties(miz, group_name="Colt 1-1", move_bearing=90, move_distance_m=5000)
        after, _ = _positions(miz, "Colt 1-1")
        deltas = {(round(a[0] - b[0], 3), round(a[1] - b[1], 3)) for a, b in zip(after, before, strict=True)}
        assert len(deltas) == 1

    def test_the_formation_keeps_its_shape(self, miz: Path) -> None:
        """Two units 250 m apart must still be 250 m apart after the move."""
        before, _ = _positions(miz, "Colt 1-1")
        spread_before = (before[1][0] - before[0][0], before[1][1] - before[0][1])
        set_group_properties(miz, group_name="Colt 1-1", move_bearing=45, move_distance_m=12000)
        after, _ = _positions(miz, "Colt 1-1")
        spread_after = (after[1][0] - after[0][0], after[1][1] - after[0][1])
        assert spread_after == pytest.approx(spread_before)

    def test_the_route_travels_with_the_units(self, miz: Path) -> None:
        """The shear case: a move that leaves the waypoints behind detaches the route.

        This is the test the ticket asks to see fail on an implementation that moves only units.
        """
        units_before, points_before = _positions(miz, "Colt 1-1")
        set_group_properties(miz, group_name="Colt 1-1", move_bearing=180, move_distance_m=8000)
        units_after, points_after = _positions(miz, "Colt 1-1")
        unit_delta = (units_after[0][0] - units_before[0][0], units_after[0][1] - units_before[0][1])
        point_delta = (points_after[0][0] - points_before[0][0], points_after[0][1] - points_before[0][1])
        assert point_delta == pytest.approx(unit_delta)

    def test_every_waypoint_moves_not_just_the_first(self, miz: Path) -> None:
        _, before = _positions(miz, "Colt 1-1")
        set_group_properties(miz, group_name="Colt 1-1", move_bearing=270, move_distance_m=3000)
        _, after = _positions(miz, "Colt 1-1")
        deltas = {(round(a[0] - b[0], 3), round(a[1] - b[1], 3)) for a, b in zip(after, before, strict=True)}
        assert len(deltas) == 1

    def test_the_group_anchor_moves_too(self, miz: Path) -> None:
        """`group.x/y` is the anchor the editor draws; leaving it behind desyncs the tree view."""
        before = _group(miz, "Colt 1-1")["x"]
        set_group_properties(miz, group_name="Colt 1-1", move_bearing=0, move_distance_m=10000)
        assert _group(miz, "Colt 1-1")["x"] != before

    def test_a_group_without_a_route_moves_fine(self, miz: Path) -> None:
        set_group_properties(miz, group_name="Ground Convoy", move_bearing=90, move_distance_m=1000)
        units, points = _positions(miz, "Ground Convoy")
        assert units and not points

    def test_altitudes_are_left_alone(self, miz: Path) -> None:
        """A horizontal move must not touch a waypoint's altitude."""
        set_group_properties(miz, group_name="Colt 1-1", move_bearing=90, move_distance_m=5000)
        points = _values((_group(miz, "Colt 1-1").get("route") or {}).get("points"))
        assert [point["alt"] for point in points] == [2000, 6000]


class TestMoveUsesTheGeodesicOffset:
    """A bearing and a distance are a lat/lon problem, not metres added to a projected x."""

    def test_the_destination_matches_the_projected_geodesic_point(self, miz: Path) -> None:
        """Pinned against `veaf_libs.coordinates` itself, so the projection cannot be bypassed."""
        lat, lon = coordinates.xy_to_latlon("Caucasus", -300000.0, 600000.0)
        expected_lat, expected_lon = coordinates.offset_latlon(lat, lon, 90.0, 5000.0)
        expected_x, expected_y = coordinates.latlon_to_xy("Caucasus", expected_lat, expected_lon)
        set_group_properties(miz, group_name="Colt 1-1", move_bearing=90, move_distance_m=5000)
        units, _ = _positions(miz, "Colt 1-1")
        assert units[0] == pytest.approx((expected_x, expected_y), abs=1.0)

    def test_a_move_to_a_target_lands_the_anchor_on_it(self, miz: Path) -> None:
        set_group_properties(miz, group_name="Colt 1-1", move_to={"x": -310000.0, "y": 615000.0})
        assert (_group(miz, "Colt 1-1")["x"], _group(miz, "Colt 1-1")["y"]) == pytest.approx((-310000.0, 615000.0))

    def test_a_move_to_a_target_still_carries_the_route(self, miz: Path) -> None:
        units_before, points_before = _positions(miz, "Colt 1-1")
        set_group_properties(miz, group_name="Colt 1-1", move_to={"x": -310000.0, "y": 615000.0})
        units_after, points_after = _positions(miz, "Colt 1-1")
        unit_delta = (units_after[0][0] - units_before[0][0], units_after[0][1] - units_before[0][1])
        point_delta = (points_after[1][0] - points_before[1][0], points_after[1][1] - points_before[1][1])
        assert point_delta == pytest.approx(unit_delta)

    def test_a_bearing_without_a_distance_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="together"):
            set_group_properties(miz, group_name="Colt 1-1", move_bearing=90)

    def test_two_ways_of_moving_at_once_are_refused(self, miz: Path) -> None:
        """`move_to` and a bearing disagree by construction; guessing which wins is worse."""
        with pytest.raises(ValueError, match="not both"):
            set_group_properties(
                miz, group_name="Colt 1-1", move_to={"x": 0.0, "y": 0.0}, move_bearing=90, move_distance_m=1000
            )

    def test_the_move_warns_it_could_not_check_the_surface(self, miz: Path) -> None:
        """No terrain data exists design-time, so the limit is said rather than implied."""
        result = set_group_properties(miz, group_name="Ground Convoy", move_bearing=90, move_distance_m=40000)
        assert any("surface" in warning for warning in result["warnings"])

    def test_the_result_reports_where_the_group_went(self, miz: Path) -> None:
        result = set_group_properties(miz, group_name="Colt 1-1", move_bearing=90, move_distance_m=5000)
        assert set(result["changed"]["position"]) >= {"from", "to"}


class TestRename:
    """A rename that breaks a VEAF convention breaks the runtime module keyed off it."""

    def test_a_plain_rename_goes_through(self, miz: Path) -> None:
        set_group_properties(miz, group_name="Colt 1-1", new_name="Viper 1-1")
        assert _group(miz, "Viper 1-1")["name"] == "Viper 1-1"

    def test_a_reserved_prefix_is_refused_by_default(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="veafSpawn-"):
            set_group_properties(miz, group_name="Colt 1-1", new_name="veafSpawn-Colt")

    def test_the_refusal_names_the_convention_it_hit(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="spawn_template"):
            set_group_properties(miz, group_name="Colt 1-1", new_name="veafSpawn-Colt")

    def test_a_trigger_zone_prefix_is_refused_because_it_despawns_the_group(self, miz: Path) -> None:
        """The convention that destroys content silently: a group named after a combat zone."""
        with pytest.raises(ValueError, match="czBatumi"):
            set_group_properties(miz, group_name="Colt 1-1", new_name="czBatumi-Colt")

    def test_an_acknowledged_convention_is_allowed_through(self, miz: Path) -> None:
        """Renaming *into* a convention is a legitimate intent — it just must be deliberate."""
        set_group_properties(miz, group_name="Colt 1-1", new_name="veafSpawn-Colt", acknowledge_conventions=True)
        assert _group(miz, "veafSpawn-Colt")["name"] == "veafSpawn-Colt"

    def test_an_acknowledged_rename_still_reports_the_warnings(self, miz: Path) -> None:
        result = set_group_properties(
            miz, group_name="Colt 1-1", new_name="veafSpawn-Colt", acknowledge_conventions=True
        )
        assert any("veafSpawn-" in warning for warning in result["warnings"])

    def test_renaming_onto_an_existing_group_is_refused(self, miz: Path) -> None:
        """Two groups sharing a name makes every later edit ambiguous, including the undo."""
        with pytest.raises(ValueError, match="already"):
            set_group_properties(miz, group_name="Colt 1-1", new_name="Ground Convoy")

    def test_the_units_are_not_renamed_with_the_group(self, miz: Path) -> None:
        """Unit names carry VEAF markers of their own; a cascade here would rewrite them blind."""
        set_group_properties(miz, group_name="Colt 1-1", new_name="Viper 1-1")
        assert [unit["name"] for unit in _values(_group(miz, "Viper 1-1").get("units"))] == [
            "Colt 1-1-1",
            "Colt 1-1-2",
        ]


class TestFrequency:
    """Gated on the airframe's own primary-frequency bound, from the shipped radio specs."""

    def test_a_frequency_inside_the_bound_is_written(self, miz: Path) -> None:
        set_group_properties(miz, group_name="Colt 1-1", frequency_mhz=305)
        assert _group(miz, "Colt 1-1")["frequency"] == 305

    def test_a_frequency_outside_the_airframe_bound_is_refused(self, miz: Path) -> None:
        """The editor would refuse to save the mission, far from here and long after."""
        with pytest.raises(ValueError, match="FA-18C_hornet"):
            set_group_properties(miz, group_name="Colt 1-1", frequency_mhz=1)

    def test_the_modulation_can_be_set_with_it(self, miz: Path) -> None:
        set_group_properties(miz, group_name="Colt 1-1", frequency_mhz=305, modulation="FM")
        assert _group(miz, "Colt 1-1")["modulation"] == 1

    def test_an_unknown_modulation_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="AM"):
            set_group_properties(miz, group_name="Colt 1-1", frequency_mhz=305, modulation="SSB")

    def test_a_ground_group_frequency_is_left_permissive(self, miz: Path) -> None:
        """An unknown or unbounded type must behave as it did before this check existed."""
        set_group_properties(miz, group_name="Ground Convoy", frequency_mhz=30)
        assert _group(miz, "Ground Convoy")["frequency"] == 30


class TestFlags:
    """Late activation, hidden and uncontrolled — cheap, and reported like the rest."""

    @pytest.mark.parametrize(
        "field,key",
        [
            ("late_activation", "lateActivation"),
            ("hidden", "hidden"),
            ("uncontrolled", "uncontrolled"),
        ],
    )
    def test_each_flag_is_written(self, miz: Path, field: str, key: str) -> None:
        set_group_properties(miz, group_name="Colt 1-1", **{field: True})
        assert _group(miz, "Colt 1-1")[key] is True

    def test_a_flag_can_be_turned_off_again(self, miz: Path) -> None:
        """`False` must mean "off", not "not given" — the trap of an optional boolean."""
        set_group_properties(miz, group_name="Colt 1-1", uncontrolled=True)
        set_group_properties(miz, group_name="Colt 1-1", uncontrolled=False)
        assert _group(miz, "Colt 1-1")["uncontrolled"] is False


class TestResultAndBackup:
    """Same contract as the unit setter: previous values, a backup, and no half-writes."""

    def test_nothing_to_change_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="no property given"):
            set_group_properties(miz, group_name="Colt 1-1")

    def test_an_unknown_group_names_what_exists(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="Ground Convoy"):
            set_group_properties(miz, group_name="Nope", new_name="Whatever")

    def test_the_result_carries_previous_values(self, miz: Path) -> None:
        result = set_group_properties(miz, group_name="Colt 1-1", frequency_mhz=305)
        assert result["changed"]["frequency"] == {"from": 251, "to": 305}

    def test_a_backup_is_taken_before_the_write(self, miz: Path) -> None:
        set_group_properties(miz, group_name="Colt 1-1", frequency_mhz=305)
        assert len([path for path in miz.parent.glob("*.miz") if path != miz]) == 1

    def test_a_refused_change_leaves_the_mission_untouched(self, miz: Path) -> None:
        before = miz.read_bytes()
        with pytest.raises(ValueError):
            set_group_properties(miz, group_name="Colt 1-1", frequency_mhz=1)
        assert miz.read_bytes() == before

    def test_one_call_can_move_rename_and_reconfigure(self, miz: Path) -> None:
        result = set_group_properties(
            miz,
            group_name="Colt 1-1",
            new_name="Viper 1-1",
            move_bearing=90,
            move_distance_m=2000,
            late_activation=True,
        )
        assert set(result["changed"]) == {"name", "position", "late_activation"}
