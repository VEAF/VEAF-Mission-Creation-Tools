"""The in-game mission check: menus, zones, missions, columns (FEAT-DCS-RECON-AND-MISSION-CHECK)."""

from __future__ import annotations

import re
from collections.abc import Iterator

import pytest
from veaf_libs import dcs_mission_check as mc
from veaf_libs.dcs_mission_check import (
    Entity,
    Report,
    count_lua,
    empty_labels,
    expected_duration,
    format_line,
    parse_inventory,
    parse_menu,
    parse_names,
    parse_speeds,
    run_checks,
    speeds_lua,
    switch_lua,
    verdict,
    zone_routed_lua,
)
from veaf_libs.i18n import language
from veaf_libs.lua_syntax import check_lua_syntax


@pytest.fixture(autouse=True)
def _english() -> Iterator[None]:
    """The assertions read the English report."""
    with language("en"):
        yield


ZONE = Entity("zone", 'Kiswah"PC', "PC de Kiswah", True, False, 9)
MISSION = Entity("mission", "CAP-Alliee-Masada/Good/1", "CAP alliée", False, False, 0)


class TestLua:
    @pytest.mark.parametrize(
        "chunk",
        [
            mc.MENU_LUA,
            mc.INVENTORY_LUA,
            mc.MISSION_ROUTED_LUA,
            switch_lua(ZONE, True),
            switch_lua(ZONE, False),
            switch_lua(MISSION, True),
            switch_lua(MISSION, False),
            count_lua(ZONE),
            count_lua(MISSION),
            zone_routed_lua(ZONE),
            speeds_lua(["a", 'b"c']),
        ],
    )
    def test_every_chunk_parses_as_lua_51(self, chunk: str) -> None:
        check_lua_syntax(chunk)

    def test_a_cap_variant_is_switched_by_its_full_name(self) -> None:
        assert '"CAP-Alliee-Masada/Good/1"' in switch_lua(MISSION, True)
        assert "ActivateMission(" in switch_lua(MISSION, True)
        assert "DesactivateMission(" in switch_lua(MISSION, False)

    def test_switching_a_zone_on_records_its_mobile_groups_and_off_removes_the_wrapper(self) -> None:
        on, off = switch_lua(ZONE, True), switch_lua(ZONE, False)
        assert "isMobile" in on and "veafMissionCheck.mobile" in on and "ActivateZone(" in on
        assert "zone.spawnElement = nil" in off and "DesactivateZone(" in off
        assert "zone.spawnElement = nil" in zone_routed_lua(ZONE)


class TestMenu:
    def test_the_tree_is_read_with_paths(self) -> None:
        nodes = parse_menu(
            "menu\t0\t=VEAF\nmenu\t1\t=Zones\ncommand\t2\t=Activer\nmenu\t1\t=Missions\ncommand\t2\t=Info"
        )
        assert [n.path for n in nodes] == [
            ("VEAF",),
            ("VEAF", "Zones"),
            ("VEAF", "Zones", "Activer"),
            ("VEAF", "Missions"),
            ("VEAF", "Missions", "Info"),
        ]

    def test_empty_and_missing_labels_are_found(self) -> None:
        nodes = parse_menu("menu\t0\t=VEAF\nmenu\t1\t=Zones\ncommand\t2\t=  \ncommand\t2\t!nil\ncommand\t1\t=OK")
        blanks = empty_labels(nodes)
        assert [n.path for n in blanks] == [("VEAF", "Zones", "∅"), ("VEAF", "Zones", "∅")]
        assert blanks[1].title is None

    def test_no_menu(self) -> None:
        assert parse_menu("absent") == []
        assert parse_menu("") == []

    def test_a_malformed_line_is_refused(self) -> None:
        with pytest.raises(ValueError):
            parse_menu("menu\tx\t=VEAF")


class TestParsers:
    def test_inventory(self) -> None:
        entities = parse_inventory(
            "zone\tSA6Sasa\tSA-6\t1\t0\t4\nzone\tOp\tOpération\t1\t1\t0\nmission\tCAP/Good/1\tCAP\t0\t0\t0"
        )
        assert entities[0] == Entity("zone", "SA6Sasa", "SA-6", True, False, 4)
        assert entities[1].operation
        assert entities[2].kind == "mission" and not entities[2].active

    def test_a_malformed_inventory_line_is_refused(self) -> None:
        with pytest.raises(ValueError):
            parse_inventory("zone\tonly")

    def test_speeds_and_names(self) -> None:
        assert parse_speeds("Col 1\t4.20\nGone\t-1.00\n") == {"Col 1": 4.2, "Gone": -1.0}
        assert parse_names("a\n\nb\n") == ["a", "b"]


class FakeDcs:
    """A mission with zones, missions and columns, answering the chunks the check sends."""

    def __init__(self) -> None:
        self.menu = "menu\t0\t=VEAF\nmenu\t1\t=Zones\ncommand\t2\t="
        self.zones = {
            "SA6Sasa": {"active": True, "operation": False, "units": 4, "routed": []},
            "Poussee": {"active": False, "operation": False, "units": 6, "routed": ["Poussee [b] col#1"]},
            "Ghost": {"active": False, "operation": False, "units": 0, "routed": []},
            "Op": {"active": True, "operation": True, "units": 0, "routed": []},
        }
        self.missions = {"CAP/Good/1": {"active": False, "units": 2}}
        self.speed = {"Poussee [b] col#1": 0.0, "Convoy": 0.0}
        self.moving = {"Convoy"}
        self.calls: list[str] = []

    def run(self, code: str) -> str:
        self.calls.append(code)
        if code == mc.MENU_LUA:
            return self.menu
        if code == mc.INVENTORY_LUA:
            lines = [
                f"zone\t{n}\t{n}\t{int(z['active'])}\t{int(z['operation'])}\t{z['units'] if z['active'] else 0}"
                for n, z in self.zones.items()
            ]
            lines += [f"mission\t{n}\t{n}\t{int(m['active'])}\t0\t0" for n, m in self.missions.items()]
            return "\n".join(lines)
        if code == mc.MISSION_ROUTED_LUA:
            return "Convoy"
        name = re.findall(r'"([^"]+)"', code)
        if "ActivateZone(" in code or "DesactivateZone(" in code:
            self.zones[name[0]]["active"] = "ActivateZone(" in code
            return "ok"
        if "ActivateMission(" in code or "DesactivateMission(" in code:
            self.missions[name[0]]["active"] = "ActivateMission(" in code
            return "ok"
        if "zoneUnits(z)" in code:
            z = self.zones[name[0]]
            return str(z["units"] if z["active"] else 0)
        if "missionUnits(m)" in code:
            m = self.missions[name[0]]
            return str(m["units"] if m["active"] else 0)
        if "veafMissionCheck.mobile[groupName]" in code:
            return "\n".join(self.zones[name[0]]["routed"])
        if "getVelocity" in code:
            # every reading after the first, the moving groups have picked up speed
            for group in self.moving:
                self.speed[group] = 5.0
            return "\n".join(f"{g}\t{self.speed.get(g, -1):.2f}" for g in name)
        raise AssertionError(f"unexpected chunk: {code[:80]}")


class TestRunChecks:
    def test_the_whole_check_reports_each_defect_and_restores_the_mission(self) -> None:
        dcs = FakeDcs()
        waits: list[float] = []
        said: list[mc.Line] = []
        report = run_checks(dcs.run, waits.append, said.append)

        texts = [line.text for line in report.lines]
        assert said == report.lines
        assert any("empty label: VEAF > Zones > ∅" in t for t in texts)
        assert any("mission: Convoy moves" in t for t in texts)
        assert any("Poussee [b] col#1 has a route and has not moved" in t for t in texts)
        assert any(t.startswith("SA6Sasa: 4 unit(s) on, 0 off, left on") for t in texts)
        assert any(t.startswith("Ghost: activated, 0 unit") for t in texts)
        assert any(t.startswith("Op: an operation, not toggled") for t in texts)
        assert any(t.startswith("CAP/Good/1: 2 unit(s) on, 0 off, left off") for t in texts)
        assert not report.passed
        # every zone and mission is back as found
        assert dcs.zones["SA6Sasa"]["active"] and not dcs.zones["Poussee"]["active"]
        assert not dcs.missions["CAP/Good/1"]["active"]
        # the frozen column was watched for the whole timeout
        assert sum(w for w in waits if w == mc.MOVE_POLL) >= mc.MOVE_TIMEOUT

    def test_a_zone_listed_twice_is_checked_once(self) -> None:
        dcs = FakeDcs()
        inventory = dcs.run(mc.INVENTORY_LUA)
        original = dcs.run

        def run(code: str) -> str:
            if code == mc.INVENTORY_LUA:
                return inventory + "\nzone\tSA6Sasa\tSA6Sasa\t1\t0\t4"
            return original(code)

        report = run_checks(run, lambda s: None, lambda line: None)
        assert sum(1 for line in report.lines if line.text.startswith("SA6Sasa:")) == 1

    def test_only_restricts_zones_and_missions(self) -> None:
        dcs = FakeDcs()
        dcs.menu = "menu\t0\t=VEAF"
        report = run_checks(dcs.run, lambda s: None, lambda line: None, only=["SA6Sasa"])
        assert [line.check for line in report.lines] == ["menu", "route", "zone"]
        assert report.passed

    def test_an_unknown_name_fails(self) -> None:
        report = Report()
        mc.check_entity(
            lambda code: "unknown", Entity("zone", "X", "X", False, False, 0), lambda s: None, report, lambda line: None
        )
        assert report.lines[0].text == "X: VEAF does not know this name"

    def test_units_left_after_deactivation_fail(self) -> None:
        report = Report()
        counts = iter(["5", "2"])

        def run(code: str) -> str:
            if "zoneUnits(z)" in code:
                return next(counts)
            return "ok" if "ActivateZone(" in code or "DesactivateZone(" in code else ""

        mc.check_entity(run, Entity("zone", "X", "", False, False, 0), lambda s: None, report, lambda line: None)
        assert report.lines[-1].text == "X: 5 unit(s) on, 2 still there once off"

    def test_a_group_that_leaves_the_map_fails(self) -> None:
        report = Report()
        mc._judge_moving(report, lambda line: None, "mission", {"Gone": -1.0})
        assert not report.passed and "left the map" in report.lines[0].text

    def test_no_menu_fails(self) -> None:
        report = Report()
        mc.check_menu(lambda code: "absent", report, lambda line: None)
        assert report.lines[0].text == "no VEAF radio menu in this mission"


class TestReport:
    def test_lines_and_verdict(self) -> None:
        report = Report()
        report.add(True, "zone", "fine")
        report.add(None, "zone", "info")
        assert "✓" in format_line(report.lines[0]) and "·" in format_line(report.lines[1])
        assert "PASS" in verdict(report) and "1 check(s)" in verdict(report)
        report.add(False, "menu", "broken")
        assert "✗" in format_line(report.lines[2])
        assert "FAIL" in verdict(report) and "1 of 2" in verdict(report)

    def test_a_group_name_is_not_read_as_markup(self) -> None:
        line = mc.Line(True, "route", "Poussee: Poussee [b] col#1 moves")
        assert "\\[b]" in format_line(line)

    def test_expected_duration_is_in_minutes(self) -> None:
        assert expected_duration(0) == 1
        assert expected_duration(12) > expected_duration(2)
