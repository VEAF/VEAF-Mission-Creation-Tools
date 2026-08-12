"""`set_unit_properties` — the first action that changes something a mission already contains.

Ticket 02 of `FEAT-MCP-MUTATION-ACTIONS`. Three shapes asserted here were **read out of real
missions** rather than assumed, and two of them contradict the ticket:

- **`skill` has seven values, not four.** `Average`, `Good`, `High`, `Excellent` and `Random` are AI
  levels; `Client` and `Player` are *human slots*. Writing an AI level over a `Client` deletes a
  multiplayer slot and writing `Client` over an AI unit creates one — `FIX-TEMPLATE-SLOTS-VISIBLE`
  is the lot that paid for slots appearing where nobody wanted them. So both directions are refused
  by name rather than silently honoured.
- **An aircraft's `callsign` is not a plain field.** It is `{1: family, 2: flight, 3: number,
  name: "Colt11"}` and `name` is the concatenation of the family's word with the two indices
  (`{1:1, 2:1, 3:2}` reads `Enfield12`). Writing `name` alone desynchronises what DCS says on the
  radio from what the editor shows, so the action edits the indices and rebuilds `name` from the
  prefix it already has. Changing the *family* needs DCS's family→word table, which this repository
  does not ship, so it is refused unless the caller passes the resulting `name` too.

`heading` is stored in **radians** while a mission maker speaks degrees, the same trap
`resolve_coordinates` hides elsewhere, so the conversion has a test pinning its direction.
"""

import math
import zipfile
from pathlib import Path

import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.set_unit_properties import set_unit_properties

#: A mission holding what this ticket mutates: an aircraft with a structured callsign and gapped
#: pylons, a wingman, a human slot, and a ground unit whose callsign is a bare number.
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
                ["units"] = {
                  [1] = {
                    ["name"] = "Colt 1-1-1",
                    ["type"] = "FA-18C_hornet",
                    ["skill"] = "High",
                    ["livery_id"] = "vfa-106 (grey)",
                    ["onboard_num"] = "101",
                    ["heading"] = 0.0,
                    ["callsign"] = {
                      [1] = 4,
                      [2] = 1,
                      [3] = 1,
                      ["name"] = "Colt11",
                    },
                    ["payload"] = {
                      ["fuel"] = "4900",
                      ["flare"] = 60,
                      ["chaff"] = 60,
                      ["gun"] = 100,
                      ["pylons"] = {
                        [1] = {
                          ["CLSID"] = "{AIM-9L}",
                        },
                        [4] = {
                          ["CLSID"] = "{Mk-82 Snakeye}",
                        },
                        [9] = {
                          ["CLSID"] = "{AIM-9L}",
                        },
                      },
                    },
                  },
                  [2] = {
                    ["name"] = "Colt 1-1-2",
                    ["type"] = "FA-18C_hornet",
                    ["skill"] = "Client",
                    ["heading"] = 1.0,
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
                ["units"] = {
                  [1] = {
                    ["name"] = "Convoy-1",
                    ["type"] = "M-1 Abrams",
                    ["skill"] = "Average",
                    ["callsign"] = 101,
                    ["heading"] = 0.0,
                  },
                },
              },
            },
          },
        },
      },
    },
  },
}
"""


@pytest.fixture
def miz(tmp_path: Path) -> Path:
    """A real `.miz` carrying the unit shapes this action has to mutate."""
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
    """Return a DCS table's entries whether it came back as a 1-based dict or a list.

    Round-tripping a mission flattens a contiguous 1-based table into a list, so a helper that
    only handles dicts passes before the write and fails after it.
    """
    if isinstance(container, dict):
        return list(container.values())
    return list(container) if isinstance(container, list) else []


def _written_pylons(miz_path: Path, group_name: str, unit_name: str) -> dict[int, str]:
    """Return the loadout on disk as ``{station: CLSID}``.

    Reading it any other way is the bug this whole ticket guards against: a contiguous pylon table
    comes back from the parser as a **list**, so `pylons[1]` is station 2 there and station 1 in the
    gapped dict case. The station number is restored from the position rather than trusted.
    """
    payload = _unit(miz_path, group_name, unit_name).get("payload") or {}
    raw = payload.get("pylons")
    if isinstance(raw, dict):
        return {int(station): entry["CLSID"] for station, entry in raw.items()}
    return {offset: entry["CLSID"] for offset, entry in enumerate(raw or [], start=1)}


def _unit(miz_path: Path, group_name: str, unit_name: str) -> dict:
    """Read one unit straight out of the written mission, to assert what landed on disk."""
    content = read_miz(miz_path).mission_content
    assert content is not None
    for coalition in _values(content.get("coalition")):
        for country in _values(coalition.get("country")):
            for category in ("plane", "helicopter", "vehicle", "ship", "static"):
                for group in _values((country.get(category) or {}).get("group")):
                    if group.get("name") != group_name:
                        continue
                    for unit in _values(group.get("units")):
                        if unit.get("name") == unit_name:
                            return unit
    raise AssertionError(f"unit not found in written mission: {group_name} / {unit_name}")


class TestAddressing:
    """A mutation addresses a unit by name, and says what it looked for when it misses."""

    def test_unknown_group_names_what_was_looked_for(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="No group named 'Viper 1-1'"):
            set_unit_properties(miz, group_name="Viper 1-1", unit_name="Colt 1-1-1", skill="Good")

    def test_unknown_group_lists_the_names_that_exist(self, miz: Path) -> None:
        """The point of the error is to let an agent retry without a second read action."""
        with pytest.raises(ValueError, match="Colt 1-1"):
            set_unit_properties(miz, group_name="Viper 1-1", unit_name="Colt 1-1-1", skill="Good")

    def test_unknown_unit_names_the_group_it_searched(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="No unit named 'Colt 1-1-9' in group 'Colt 1-1'"):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-9", skill="Good")

    def test_unknown_unit_lists_the_units_the_group_holds(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="Colt 1-1-2"):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-9", skill="Good")

    def test_a_group_name_is_exact_not_a_fragment(self, miz: Path) -> None:
        """`describe_units` filters on a fragment; a *mutation* must not guess which group.

        "Colt" matches one group today and would match three in a real mission, so accepting a
        fragment here means an edit landing on whichever group happened to be first.
        """
        with pytest.raises(ValueError, match="No group named 'Colt'"):
            set_unit_properties(miz, group_name="Colt", unit_name="Colt 1-1-1", skill="Good")

    def test_nothing_to_change_is_refused_rather_than_a_silent_no_op(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="no property given"):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1")


class TestSkill:
    """The seven values are not interchangeable: five are AI levels, two are human slots."""

    @pytest.mark.parametrize("skill", ["Average", "Good", "High", "Excellent", "Random"])
    def test_every_ai_level_is_accepted(self, miz: Path, skill: str) -> None:
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", skill=skill)
        assert _unit(miz, "Colt 1-1", "Colt 1-1-1")["skill"] == skill

    def test_unknown_skill_is_refused_naming_the_valid_ones(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="Excellent"):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", skill="Legendary")

    def test_turning_an_ai_unit_into_a_human_slot_is_refused(self, miz: Path) -> None:
        """`Client`/`Player` are not skill levels — they add a slot to the multiplayer list.

        `FIX-TEMPLATE-SLOTS-VISIBLE` is the lot that paid for slots appearing where nobody put
        them, so this is refused with the reason rather than honoured as a skill.
        """
        with pytest.raises(ValueError, match="human slot"):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", skill="Client")

    def test_taking_a_human_slot_away_is_refused_too(self, miz: Path) -> None:
        """The same mistake in the other direction: an AI level over a `Client` deletes the slot."""
        with pytest.raises(ValueError, match="human slot"):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-2", skill="High")

    def test_a_human_slot_keeps_its_other_properties_editable(self, miz: Path) -> None:
        """Refusing the skill change must not lock the whole unit."""
        result = set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-2", heading_deg=90)
        assert result["changed"]["heading"]["to"] == pytest.approx(math.pi / 2)


class TestHeading:
    """Degrees in, radians out — and the direction is pinned, not assumed."""

    def test_ninety_degrees_is_a_quarter_turn_in_radians(self, miz: Path) -> None:
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", heading_deg=90)
        assert _unit(miz, "Colt 1-1", "Colt 1-1-1")["heading"] == pytest.approx(math.pi / 2)

    def test_the_result_reports_degrees_as_well_as_radians(self, miz: Path) -> None:
        """An agent telling the mission maker "now facing 90°" must not have to convert back."""
        result = set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", heading_deg=90)
        assert result["changed"]["heading"]["to_degrees"] == pytest.approx(90.0)

    def test_a_negative_bearing_is_normalised_onto_the_compass(self, miz: Path) -> None:
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", heading_deg=-90)
        assert _unit(miz, "Colt 1-1", "Colt 1-1-1")["heading"] == pytest.approx(3 * math.pi / 2)

    def test_a_bearing_past_a_full_turn_is_normalised(self, miz: Path) -> None:
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", heading_deg=450)
        assert _unit(miz, "Colt 1-1", "Colt 1-1-1")["heading"] == pytest.approx(math.pi / 2)


class TestLoadout:
    """The pylon table is keyed by station number, and the numbers are not contiguous."""

    def test_replace_writes_exactly_the_stations_given(self, miz: Path) -> None:
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={2: "{Mk-84}", 8: "{AIM-120C}"})
        assert set(_written_pylons(miz, "Colt 1-1", "Colt 1-1-1")) == {2, 8}

    def test_replace_keeps_the_station_numbers_it_was_given(self, miz: Path) -> None:
        """A positional write would renumber 2 and 8 into 1 and 2, hanging weapons elsewhere."""
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={2: "{Mk-84}", 8: "{AIM-120C}"})
        assert _written_pylons(miz, "Colt 1-1", "Colt 1-1-1")[8] == "{AIM-120C}"

    def test_merge_leaves_the_stations_it_was_not_given_alone(self, miz: Path) -> None:
        set_unit_properties(
            miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={4: "{Mk-84}"}, pylons_mode="merge"
        )
        assert set(_written_pylons(miz, "Colt 1-1", "Colt 1-1-1")) == {1, 4, 9}

    def test_merge_replaces_the_station_it_was_given(self, miz: Path) -> None:
        set_unit_properties(
            miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={4: "{Mk-84}"}, pylons_mode="merge"
        )
        assert _written_pylons(miz, "Colt 1-1", "Colt 1-1-1")[4] == "{Mk-84}"

    def test_merge_empties_a_station_given_an_empty_weapon(self, miz: Path) -> None:
        """ "Take the bombs off pylon 4" is a sentence; it needs a way to say "nothing here"."""
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={4: ""}, pylons_mode="merge")
        assert set(_written_pylons(miz, "Colt 1-1", "Colt 1-1-1")) == {1, 9}

    def test_the_rest_of_the_payload_survives_a_loadout_change(self, miz: Path) -> None:
        """Fuel, chaff, flares and gun live in the same table and are not this action's business."""
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={2: "{Mk-84}"})
        payload = _unit(miz, "Colt 1-1", "Colt 1-1-1")["payload"]
        assert payload["fuel"] == "4900"
        assert payload["chaff"] == 60

    @pytest.mark.parametrize("station", [0, -3])
    def test_a_station_number_below_one_is_an_error(self, miz: Path, station: int) -> None:
        with pytest.raises(ValueError, match="station"):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={station: "{Mk-84}"})

    def test_a_non_numeric_station_is_an_error_not_a_dropped_key(self, miz: Path) -> None:
        """The ticket's rule: a bad pylon index is an error, never a silently dropped key."""
        with pytest.raises(ValueError, match="station"):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={"left": "{Mk-84}"})

    def test_an_empty_loadout_in_replace_mode_strips_the_aircraft(self, miz: Path) -> None:
        """Explicit, because `{}` could as easily mean "no change" — here it means "clean".

        `pylons=None` is "no change"; `pylons={}` is "carry nothing", which is how a mission maker
        asks for a clean airframe.
        """
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={})
        assert _written_pylons(miz, "Colt 1-1", "Colt 1-1-1") == {}

    def test_a_unit_without_a_payload_gains_one(self, miz: Path) -> None:
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-2", pylons={1: "{AIM-9L}"})
        assert _written_pylons(miz, "Colt 1-1", "Colt 1-1-2")[1] == "{AIM-9L}"

    def test_the_action_warns_that_it_cannot_check_a_clsid(self, miz: Path) -> None:
        """No per-airframe weapon table ships here, so the limit is stated instead of implied.

        DCS drops a weapon its airframe cannot carry without an error, so an unchecked CLSID is a
        silent failure the caller has to know about.
        """
        result = set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={2: "{Mk-84}"})
        assert any("CLSID" in warning for warning in result["warnings"])


class TestCallsign:
    """An aircraft callsign is a structured table whose `name` must stay in sync."""

    def test_changing_flight_and_number_rebuilds_the_name(self, miz: Path) -> None:
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", callsign={"flight": 2, "number": 3})
        assert _unit(miz, "Colt 1-1", "Colt 1-1-1")["callsign"]["name"] == "Colt23"

    def test_changing_flight_and_number_keeps_the_family_index(self, miz: Path) -> None:
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", callsign={"flight": 2, "number": 3})
        assert _unit(miz, "Colt 1-1", "Colt 1-1-1")["callsign"][1] == 4

    def test_changing_the_family_without_its_word_is_refused(self, miz: Path) -> None:
        """DCS's family→word table is not in this repository, so the name cannot be derived."""
        with pytest.raises(ValueError, match="name"):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", callsign={"family": 5, "number": 1})

    def test_a_family_change_carrying_its_name_is_accepted(self, miz: Path) -> None:
        set_unit_properties(
            miz,
            group_name="Colt 1-1",
            unit_name="Colt 1-1-1",
            callsign={"family": 5, "flight": 1, "number": 1, "name": "Dodge11"},
        )
        assert _unit(miz, "Colt 1-1", "Colt 1-1-1")["callsign"]["name"] == "Dodge11"

    def test_a_ground_unit_keeps_its_bare_number(self, miz: Path) -> None:
        """A vehicle's callsign is a plain number, not a table — writing a table would break it."""
        set_unit_properties(miz, group_name="Ground Convoy", unit_name="Convoy-1", callsign=202)
        assert _unit(miz, "Ground Convoy", "Convoy-1")["callsign"] == 202

    @pytest.mark.parametrize("field,value", [("flight", 0), ("number", 10)])
    def test_an_index_outside_one_to_nine_is_refused(self, miz: Path, field: str, value: int) -> None:
        with pytest.raises(ValueError, match="1..9"):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", callsign={field: value})


class TestPlainFields:
    """Livery and onboard number, plus the warning the livery cannot be checked."""

    def test_livery_is_written(self, miz: Path) -> None:
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", livery="vfa-25")
        assert _unit(miz, "Colt 1-1", "Colt 1-1-1")["livery_id"] == "vfa-25"

    def test_livery_warns_that_it_cannot_be_validated(self, miz: Path) -> None:
        """DCS shows the default skin for an unknown livery with no error at all."""
        result = set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", livery="vfa-25")
        assert any("livery" in warning for warning in result["warnings"])

    def test_onboard_number_is_written_as_a_string(self, miz: Path) -> None:
        """DCS stores it as text — `"010"` keeps its leading zero, `10` would not."""
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", onboard_num="010")
        assert _unit(miz, "Colt 1-1", "Colt 1-1-1")["onboard_num"] == "010"


class TestResultAndBackup:
    """Read-before-write, and the backup every editor-parity action takes."""

    def test_the_result_carries_the_previous_value(self, miz: Path) -> None:
        result = set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", skill="Average")
        assert result["changed"]["skill"] == {"from": "High", "to": "Average"}

    def test_the_result_carries_the_previous_loadout(self, miz: Path) -> None:
        """An agent that cannot report what it replaced cannot let a mission maker undo it."""
        result = set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", pylons={2: "{Mk-84}"})
        assert result["changed"]["pylons"]["from"] == {1: "{AIM-9L}", 4: "{Mk-82 Snakeye}", 9: "{AIM-9L}"}

    def test_untouched_fields_are_absent_from_the_report(self, miz: Path) -> None:
        result = set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", skill="Average")
        assert set(result["changed"]) == {"skill"}

    def test_the_unit_and_group_are_echoed_back(self, miz: Path) -> None:
        result = set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", skill="Average")
        assert (result["group"], result["unit"]) == ("Colt 1-1", "Colt 1-1-1")

    def test_a_backup_is_taken_before_the_write(self, miz: Path) -> None:
        """A timestamped sibling, the way every other editor-parity action does it."""
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", skill="Average")
        siblings = [path for path in miz.parent.glob("*.miz") if path != miz]
        assert len(siblings) == 1

    def test_a_refused_change_leaves_the_mission_untouched(self, miz: Path) -> None:
        """A validation error must not half-write: the skill is checked before anything is stored."""
        before = miz.read_bytes()
        with pytest.raises(ValueError):
            set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", skill="Legendary")
        assert miz.read_bytes() == before

    def test_one_call_can_change_several_fields(self, miz: Path) -> None:
        result = set_unit_properties(
            miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", skill="Good", livery="vfa-25", heading_deg=180
        )
        assert set(result["changed"]) == {"skill", "livery", "heading"}

    def test_the_mission_still_reads_back_after_the_write(self, miz: Path) -> None:
        """The cheapest guard against a write the DCS editor would reject: it must re-parse."""
        set_unit_properties(miz, group_name="Colt 1-1", unit_name="Colt 1-1-1", skill="Good")
        content = read_miz(miz).mission_content
        assert content is not None
