"""Tests for the scenery lookup — the ids a combat zone's ``scenery_targets`` needs (FEAT-OBJECTIVE-MISSION-PROMPT).

DCS is never reached here: the transport is a fake that answers in the format the Lua chunk writes, so
what is tested is the chunk sent and the parsing of its answer. Whether ``world.searchObjects`` really
returns the map objects is a measurement in game, listed in the lot.
"""

import pytest
from veaf_libs.scenery_lookup import SceneryLookupError, lookup_scenery, offer_lookup, parse_point


def test_the_chunk_searches_scenery_around_each_point_in_dcs_axes() -> None:
    """Mission ``y`` is DCS ``z``: a point sent the wrong way round searches 100 km away, silently."""
    sent: list[str] = []

    def exec_lua(code: str) -> str:
        sent.append(code)
        return ""

    lookup_scenery(exec_lua, [(1000.0, 2000.0, 150.0)])

    assert "Object.Category.SCENERY" in sent[0]
    assert "x = 1000.0, z = 2000.0, r = 150.0" in sent[0]


def test_each_object_comes_back_with_its_point_id_type_and_distance() -> None:
    """The id is what goes into ``scenery_targets``; the distance says which building is the one."""

    def exec_lua(_code: str) -> str:
        return "1\t156696667\tBRIDGE_1\t1030.0\t2040.0\n1\t42\tHOUSE\t1000.0\t2000.0\n"

    found = lookup_scenery(exec_lua, [(1000.0, 2000.0, 150.0)])

    assert [(o.point, o.id, o.type_name) for o in found] == [(1, 42, "HOUSE"), (1, 156696667, "BRIDGE_1")]
    assert found[0].distance == 0.0
    assert found[1].distance == 50.0


def test_a_point_whose_search_failed_does_not_take_the_others_with_it() -> None:
    """DCS raising on one point is reported for that point; the other points still answer."""

    def exec_lua(_code: str) -> str:
        return "1\t!\tsomething broke\n2\t42\tHOUSE\t0.0\t0.0\n"

    found = lookup_scenery(exec_lua, [(5000.0, 5000.0, 100.0), (0.0, 0.0, 100.0)])

    assert [(o.point, o.id) for o in found] == [(2, 42)]


def test_an_answer_that_is_not_the_format_is_refused() -> None:
    """A transport that returns something else must not become an empty list."""

    def exec_lua(_code: str) -> str:
        return "not a scenery line"

    with pytest.raises(SceneryLookupError):
        lookup_scenery(exec_lua, [(0.0, 0.0, 100.0)])


@pytest.mark.parametrize(
    ("spec", "expected"),
    [("1000,2000", (1000.0, 2000.0, 150.0)), ("1000, 2000, 50", (1000.0, 2000.0, 50.0))],
)
def test_a_point_is_x_y_and_an_optional_radius(spec: str, expected: tuple[float, float, float]) -> None:
    """The radius defaults to a size that holds one site and not the whole town."""
    assert parse_point(spec) == expected


@pytest.mark.parametrize("spec", ["1000", "a,b", "1,2,-5", "1,2,3,4"])
def test_a_malformed_point_is_refused(spec: str) -> None:
    """A typo in a point must stop the command, not search somewhere else."""
    with pytest.raises(ValueError):
        parse_point(spec)


def test_the_offer_launches_nothing_and_names_the_command() -> None:
    """Like the clear-ground check: the MCP proposes, the user runs it with DCS."""
    offer = offer_lookup("Syria", [(1000.0, 2000.0, 150.0)])

    assert offer["launched"] is False
    assert offer["command"] == r".\veaf-tools.exe dcs scenery-objects Syria --around 1000.0,2000.0,150.0"
