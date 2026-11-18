"""Reconnaissance photos: camera, projection, live units, shots and the shooting mission (FEAT-DCS-RECON-AND-MISSION-CHECK)."""

from __future__ import annotations

import json
import math
import zipfile
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import create_miz, read_member, read_miz, write_miz
from PIL import Image
from veaf_libs import dcs_recon
from veaf_libs.blank_mission import generate_blank_mission
from veaf_libs.dcs_mission_check import derive_check_mission
from veaf_libs.dcs_recon import (
    INFO_BAR_PX,
    MAX_SLANT,
    MIN_SLANT,
    ZONES_LUA,
    CombatZone,
    LiveUnit,
    MissionInfo,
    Shot,
    ShotPlan,
    activate_alone_lua,
    airbase_lua,
    auto_slant,
    briefing_sidecar,
    camera_for,
    camera_lua,
    camera_of,
    clear_sky,
    deactivate_lua,
    derive_recon_mission,
    load_objectives,
    load_plan,
    parse_info,
    parse_point,
    parse_units,
    parse_zones,
    plan_from_zones,
    project,
    recon_mission_path,
    seconds_of_day,
    select_units,
    shoot_plan,
    shot_metadata,
    target_of,
    zone_of,
    zone_units_lua,
)
from veaf_libs.i18n import language
from veaf_libs.lua_syntax import check_lua_syntax


@pytest.fixture(autouse=True)
def _english() -> Iterator[None]:
    """The assertions read the English report."""
    with language("en"):
        yield


def _norm(v: tuple[float, float, float]) -> float:
    return math.sqrt(sum(c * c for c in v))


def _dot(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    return sum(x * y for x, y in zip(a, b, strict=True))


class TestCamera:
    def test_the_basis_is_orthonormal(self) -> None:
        cam = camera_for(1000, 2000, 300, heading=73, pitch=30, slant=900)
        for v in (cam.forward, cam.up, cam.right):
            assert _norm(v) == pytest.approx(1)
        assert _dot(cam.forward, cam.up) == pytest.approx(0, abs=1e-9)
        assert _dot(cam.forward, cam.right) == pytest.approx(0, abs=1e-9)
        assert _dot(cam.up, cam.right) == pytest.approx(0, abs=1e-9)

    def test_looking_north_down_30_degrees(self) -> None:
        cam = camera_for(0, 0, 100, heading=0, pitch=30, slant=1000)
        # x is north, y altitude, z east: the camera stands south of the target and above it.
        assert cam.position[0] == pytest.approx(-1000 * math.cos(math.radians(30)))
        assert cam.position[1] == pytest.approx(100 + 500)
        assert cam.position[2] == pytest.approx(0, abs=1e-9)
        assert cam.right == pytest.approx((0, 0, 1))  # east is on the right when looking north

    def test_looking_east_puts_the_camera_west(self) -> None:
        cam = camera_for(0, 0, 0, heading=90, pitch=0, slant=500)
        assert cam.position == pytest.approx((0, 0, -500), abs=1e-9)
        assert cam.right == pytest.approx((-1, 0, 0), abs=1e-9)  # south is on the right when looking east

    def test_the_request_is_lua_naming_the_four_vectors(self) -> None:
        lua = camera_lua(camera_for(0, 0, 0, 45, 30, 1000))
        check_lua_syntax(lua)
        assert lua.startswith("LoSetCameraPosition({x={")
        assert ",p={" in lua and lua.endswith("return 'ok'")


class TestProjection:
    def test_the_target_lands_in_the_centre_of_the_window(self) -> None:
        cam = camera_for(500, -300, 250, heading=120, pitch=35, slant=1100)
        assert project(cam, 500, -300, 250, 2560, 1440) == pytest.approx((1280, 720))

    def test_a_point_to_the_right_projects_to_the_right(self) -> None:
        cam = camera_for(0, 0, 0, heading=0, pitch=0, slant=1000)
        px, py = project(cam, 0, 100, 0, 2000, 1000) or (0.0, 0.0)
        # 80° horizontal field: focal = 1000 / tan(40°); 100 m right at 1000 m depth.
        assert px == pytest.approx(1000 + (1000 / math.tan(math.radians(40))) * 0.1)
        assert py == pytest.approx(500)

    def test_a_point_above_projects_upwards(self) -> None:
        cam = camera_for(0, 0, 0, heading=0, pitch=0, slant=1000)
        _, py = project(cam, 0, 0, 50, 2000, 1000) or (0.0, 0.0)
        assert py < 500

    def test_a_point_behind_the_camera_has_no_projection(self) -> None:
        cam = camera_for(0, 0, 0, heading=0, pitch=0, slant=1000)
        assert project(cam, -2000, 0, 0, 2000, 1000) is None


class TestLiveUnits:
    def test_the_units_request_parses_as_lua(self) -> None:
        check_lua_syntax(dcs_recon.UNITS_LUA)
        check_lua_syntax(dcs_recon.INFO_LUA)

    def test_units_and_statics_are_read(self) -> None:
        text = "unit\t1\tSA11Kiswah [r] battery#1\tSA-11 Buk LN 9A310M1\t-181477.0\t31552.0\t691.0\nstatic\t1\tCentre de commandement\t.Command Center\t-183811.0\t25553.0\t780.0\n"
        units = parse_units(text)
        assert units == [
            LiveUnit("unit", 1, "SA11Kiswah [r] battery#1", "SA-11 Buk LN 9A310M1", -181477.0, 31552.0, 691.0),
            LiveUnit("static", 1, "Centre de commandement", ".Command Center", -183811.0, 25553.0, 780.0),
        ]

    def test_an_empty_reply_is_no_unit(self) -> None:
        assert parse_units("") == []

    def test_a_malformed_line_is_refused(self) -> None:
        with pytest.raises(ValueError, match="unexpected unit line"):
            parse_units("unit\t1\tonly three")

    def test_mission_info(self) -> None:
        info = parse_info("Syria\t2011-04-16\t41460")
        assert info == MissionInfo("Syria", "2011-04-16", 41460)
        assert info.clock == "11:31"

    def test_mission_time_past_midnight_wraps(self) -> None:
        assert MissionInfo("Syria", "2011-04-16", 86400 + 3600).clock == "01:00"

    def test_malformed_info_is_refused(self) -> None:
        with pytest.raises(ValueError):
            parse_info("Syria")


UNITS = [
    LiveUnit("unit", 1, "SA6Sasa [r] battery#2", "Kub 1S91 str", 100, 200, 800),
    LiveUnit("unit", 1, "SA6Sasa [r] battery#2", "Kub 2P25 ln", 300, 400, 820),
    LiveUnit("unit", 2, "SA6Sasa-blue", "M1A2", 0, 0, 0),
    LiveUnit("static", 1, "Bunker 2", ".Command Center", 1000, 1000, 700),
    LiveUnit("unit", 1, "Kiswah [r] Air Defense#3", "ZSU-23-4 Shilka", 5000, 5000, 600),
    LiveUnit("unit", 1, "Kiswah [r] Air Defense#3", "ZSU-23-4 Shilka", 5100, 5100, 600),
]


class TestShots:
    def test_units_are_selected_by_side_and_prefix(self) -> None:
        assert [u.type for u in select_units(UNITS, 1, ["SA6Sasa"])] == ["Kub 1S91 str", "Kub 2P25 ln"]
        assert [u.group for u in select_units(UNITS, 1, ["Bunker"])] == ["Bunker 2"]

    def test_the_target_is_the_centroid(self) -> None:
        assert target_of(UNITS[:2]) == (200, 300, 810)

    def test_no_unit_no_target(self) -> None:
        with pytest.raises(ValueError):
            target_of([])

    def test_the_zone_is_read_from_a_spawned_group_name(self) -> None:
        assert zone_of("KhanArnabah [r] SA15#10388") == "KhanArnabah"
        assert zone_of("Poussee [b] column#1") == "Poussee"
        assert zone_of("Bunker 2") == "Bunker 2"

    def test_a_spawned_group_with_nothing_after_its_marker_is_of_its_zone(self) -> None:
        # "Sasa [r]" was its own zone, and the briefing dropped the photos of Sa'sa' (FIX-BRIEFING-PARITY-MARTEAU 01)
        assert zone_of("Sasa [r]") == "Sasa"
        assert zone_of("Kiswah [r]#12") == "Kiswah"
        assert zone_of("Kiswah [b]") == "Kiswah"

    def test_a_starter_plan_has_one_shot_per_combat_zone(self) -> None:
        zones = [CombatZone("combatZone_Beslan", 1000, 0, 2000), CombatZone("Kiswah", 0, 1000, 500)]
        plan, missing = plan_from_zones(zones, "red", "Marteau du Golan")
        assert missing == []
        assert plan["operation"] == "Marteau du Golan" and plan["coalition"] == "red"
        assert [s["zone"] for s in plan["shots"]] == ["combatZone_Beslan", "Kiswah"]
        assert [s["name"] for s in plan["shots"]] == ["01-beslan", "02-kiswah"]
        assert all(s["heading"] == 0 and s["slant"] == "auto" and "groups" not in s for s in plan["shots"])

    def test_a_plan_follows_the_objectives_and_looks_from_the_airbase(self) -> None:
        zones = [CombatZone("A", 1000, 0, 0), CombatZone("B", 0, 1000, 0), CombatZone("C", 0, 0, 0)]
        plan, missing = plan_from_zones(zones, "red", "", [("B", "Bravo"), ("Z", "Zulu"), ("A", "Alpha")], (0, 0))
        assert missing == ["Z"]
        assert [(s["zone"], s["title"], s["heading"]) for s in plan["shots"]] == [("B", "Bravo", 90), ("A", "Alpha", 0)]
        assert [s["name"] for s in plan["shots"]] == ["01-b", "02-a"]

    def test_objectives_are_read_from_the_briefing_words(self, tmp_path: Path) -> None:
        path = tmp_path / "kneeboard.json"
        path.write_text(
            json.dumps(
                {"title": "OT", "objectives": [{"zone": "z1", "title": "Un"}, {"title": "no zone"}, {"zone": "z2"}]}
            ),
            encoding="utf-8",
        )
        assert load_objectives(path) == [("z1", "Un"), ("z2", "z2")]
        path.write_text("{}", encoding="utf-8")
        with pytest.raises(ValueError, match="objectives"):
            load_objectives(path)

    def test_the_automatic_slant_fits_the_spread_within_bounds(self) -> None:
        def at(*points: tuple[float, float]) -> list[LiveUnit]:
            return [LiveUnit("unit", 1, "g", "T-72B", x, z, 0) for x, z in points]

        assert auto_slant(at((0, 0))) == MIN_SLANT
        assert auto_slant(at((0, 0), (0, 1000))) == 1500
        assert auto_slant(at((0, 0), (0, 12000))) == MAX_SLANT  # Beslan: 18.3 km proposed, nothing visible

    def test_zones_and_points_are_read(self) -> None:
        assert parse_zones("A\t1.0\t2.0\t300.0\n\n") == [CombatZone("A", 1.0, 2.0, 300.0)]
        with pytest.raises(ValueError):
            parse_zones("A\t1.0")
        assert parse_point("10.5\t-3.0") == (10.5, -3.0)
        assert parse_point("") is None

    @pytest.mark.parametrize(
        "code",
        [
            ZONES_LUA,
            zone_units_lua('Zone "x"'),
            activate_alone_lua("Zone"),
            deactivate_lua("Zone"),
            airbase_lua("Batumi"),
        ],
    )
    def test_the_zone_requests_parse_as_lua(self, code: str) -> None:
        check_lua_syntax(code)

    def test_a_shots_file_is_loaded(self, tmp_path: Path) -> None:
        path = tmp_path / "shots.yaml"
        path.write_text(
            "operation: Marteau du Golan\ncoalition: red\nshots:\n"
            "  - name: 02-sa6\n    title: Batterie SA-6\n    groups: [SA6Sasa]\n    heading: 47\n"
            "    mark: units\n    labels: {'Kub 1S91': RADAR}\n",
            encoding="utf-8",
        )
        plan = load_plan(path)
        assert plan.operation == "Marteau du Golan"
        assert plan.shots == [
            Shot("02-sa6", "Batterie SA-6", ["SA6Sasa"], 47.0, 30.0, None, "units", {"Kub 1S91": "RADAR"}, "SA6Sasa")
        ]

    @pytest.mark.parametrize(
        ("body", "message"),
        [
            ("shots: []\n", "no shots"),
            ("coalition: green\nshots: [{name: a, groups: [x]}]\n", "red or blue"),
            ("shots: [{name: a}]\n", "groups or a zone"),
            ("shots: [{name: a, zone: z, slant: far}]\n", "metres or auto"),
            ("shots: [{name: a, groups: [x], mark: arrows}]\n", "groups or units"),
        ],
    )
    def test_a_bad_shots_file_is_refused(self, tmp_path: Path, body: str, message: str) -> None:
        path = tmp_path / "shots.yaml"
        path.write_text(body, encoding="utf-8")
        with pytest.raises(ValueError, match=message):
            load_plan(path)

    def test_metadata_round_trips_the_camera(self) -> None:
        cam = camera_for(200, 300, 810, 47, 30, 1000)
        meta = shot_metadata(
            Shot("02-sa6", "SA-6", ["SA6Sasa"], 47),
            cam,
            UNITS[:2],
            (200, 300, 810),
            MissionInfo("Syria", "2011-04-16", 41460),
            (2560, 1440),
            (33.1, 35.9),
        )
        json.dumps(meta)
        assert camera_of(meta) == cam
        assert meta["window"] == {"width": 2560, "height": 1440, "cropped_bottom": INFO_BAR_PX}
        assert meta["target"]["lat"] == 33.1 and meta["time"] == "11:31"
        assert len(meta["units"]) == 2
        assert meta["zone"] == "SA6Sasa"

    def test_the_zone_defaults_to_the_first_prefix_and_can_be_named(self) -> None:
        assert Shot("a", "A", ["KhanArnabah [r] SA15"]).zone == "KhanArnabah"
        assert Shot("a", "A", ["KhanArnabah [r] SA15"], zone="Khan").zone == "Khan"

    def test_the_briefing_sidecar_follows_the_briefing_interface(self) -> None:
        cam = camera_for(200, 300, 810, 359.6, 30, 1000)
        meta = shot_metadata(
            Shot("02-sa6", "SA-6", ["SA6Sasa"], 359.6),
            cam,
            UNITS[:2],
            (200, 300, 810),
            MissionInfo("Syria", "2011-04-16", 41460),
            (2560, 1440),
            None,
        )
        sidecar = briefing_sidecar(meta, 3)
        assert sidecar == {
            "zone": "SA6Sasa",
            "title": "SA-6",
            "heading": 0,
            "pitch": -30,
            "x": cam.position[0],
            "y": cam.position[2],
            "altitude_m": round(cam.position[1]),
            "order": 3,
        }

    def test_a_shot_taken_with_a_bare_marker_zone_is_read_again(self) -> None:
        # the raw shots of "Marteau du Golan" carry "Sasa [r]": re-rendering them gives the briefing "Sasa"
        cam = camera_for(200, 300, 810, 90, 30, 1000)
        meta = shot_metadata(
            Shot("10-sasa", "Sasa", ["Sasa [r]"], 90),
            cam,
            UNITS[:2],
            (200, 300, 810),
            MissionInfo("Syria", "2011-04-16", 41460),
            (2560, 1440),
            None,
        )
        assert briefing_sidecar({**meta, "zone": "Sasa [r]"}, 1)["zone"] == "Sasa"


def _lines(units: list[LiveUnit]) -> str:
    return "\n".join(f"{u.kind}\t{u.side}\t{u.group}\t{u.type}\t{u.x}\t{u.z}\t{u.alt}" for u in units)


class FakeMission:
    """The scripting state of a mission with one combat zone, ``Beslan``, whose boat moves at each read."""

    def __init__(self) -> None:
        self.calls: list[str] = []
        self.reads = 0

    def run(self, code: str) -> str:
        if code == dcs_recon.ZONES_LUA:
            self.calls.append("zones")
            return "Beslan\t5000.0\t5000.0\t2000.0"
        if code == dcs_recon.INFO_LUA:
            return "Syria\t2011-04-16\t41460"
        if code == dcs_recon.UNITS_LUA:
            self.calls.append("units")
            return _lines(UNITS)
        if code == activate_alone_lua("Beslan"):
            self.calls.append("activate Beslan")
            return "ok"
        if code == deactivate_lua("Beslan"):
            self.calls.append("deactivate Beslan")
            return "ok"
        if code == zone_units_lua("Beslan"):
            self.calls.append("zone units")
            self.reads += 1
            boat = LiveUnit("unit", 1, "Beslan [r] boat#1", "speedboat", 5000 + 100 * self.reads, 5000, 0)
            blue = LiveUnit("unit", 2, "Beslan [b] crew#2", "Hummer", 5000, 5000, 0)
            return _lines([boat, blue])
        raise AssertionError(f"unexpected chunk: {code[:60]}")


class TestShootPlan:
    @staticmethod
    def _grab(retry: Any) -> tuple[Image.Image, tuple[int, int]]:
        return Image.new("RGB", (640, 360), (90, 90, 90)), (640, 360)

    def test_a_shot_by_name_prefix_places_the_camera_twice_grabs_and_writes(self, tmp_path: Path) -> None:
        mission, exported, waits, lines = FakeMission(), [], [], []
        plan = ShotPlan(
            "Golan",
            "red",
            [
                Shot("01-sa6", "SA-6", ["SA6Sasa"], 47, slant=1000),
                Shot("02-none", "Nothing", ["Absent"]),
                Shot("03-k", "K", ["Kiswah"]),
            ],
        )
        taken = shoot_plan(
            plan,
            tmp_path,
            run_server=mission.run,
            run_export=exported.append,
            grab=self._grab,
            latlon_of=lambda theatre, x, z: (33.0, 36.0),
            sleep=waits.append,
            progress=lines.append,
            only=["01-sa6", "02-none"],
            warmup=0,
        )
        assert [m["name"] for m in taken] == ["01-sa6"]
        assert len(exported) == 2 and exported[0] == exported[1]
        assert waits == [dcs_recon.SCENERY_PAUSE, dcs_recon.SETTLE_PAUSE]
        assert "activate Beslan" not in mission.calls
        assert Image.open(tmp_path / "01-sa6.png").size == (640, 360 - INFO_BAR_PX)
        meta = json.loads((tmp_path / "01-sa6.json").read_text(encoding="utf-8"))
        assert meta["window"]["height"] == 360 and meta["target"]["lat"] == 33.0 and meta["slant_m"] == 1000
        assert any("nothing matches" in line for line in lines)
        assert not (tmp_path / "03-k.png").exists()

    def test_a_combat_zone_is_shot_alone_warmed_up_and_read_at_the_grab(self, tmp_path: Path) -> None:
        mission, exported, waits = FakeMission(), [], []
        plan = ShotPlan("OT", "red", [Shot("01-beslan", "Beslan", [], 90, zone="Beslan")])
        taken = shoot_plan(
            plan,
            tmp_path,
            run_server=mission.run,
            run_export=exported.append,
            grab=self._grab,
            latlon_of=lambda theatre, x, z: None,
            sleep=waits.append,
            progress=lambda line: None,
            warmup=10,
        )
        assert mission.calls == [
            "zones",
            "activate Beslan",
            "zone units",
            "zone units",
            "zone units",
            "deactivate Beslan",
        ]
        assert waits == [
            dcs_recon.SPAWN_WAIT,
            10,
            dcs_recon.SCENERY_PAUSE,
            dcs_recon.SETTLE_PAUSE,
            dcs_recon.DESPAWN_WAIT,
        ]
        # the warm-up order, then the shot's order twice, aimed where the boat stood after the warm-up
        assert len(exported) == 3 and exported[0] != exported[1] == exported[2]
        meta = taken[0]
        assert meta["target"]["x"] == 5200
        # the rings are drawn where the boat was just before the grab, the blue crew left out
        assert [(u["group"], u["x"]) for u in meta["units"]] == [("Beslan [r] boat#1", 5300)]
        assert meta["slant_m"] == dcs_recon.MIN_SLANT

    def test_a_zone_is_deactivated_even_when_the_shot_fails(self, tmp_path: Path) -> None:
        mission = FakeMission()

        def broken(retry: Any) -> tuple[Image.Image, tuple[int, int]]:
            raise RuntimeError("no picture")

        with pytest.raises(RuntimeError, match="no picture"):
            shoot_plan(
                ShotPlan("OT", "red", [Shot("01-beslan", "Beslan", [], zone="Beslan")]),
                tmp_path,
                run_server=mission.run,
                run_export=lambda code: None,
                grab=broken,
                latlon_of=lambda theatre, x, z: None,
                sleep=lambda seconds: None,
                progress=lambda line: None,
            )
        assert mission.calls[-1] == "deactivate Beslan"


class TestShootingMission:
    @pytest.fixture
    def miz(self, tmp_path: Path) -> Path:
        files = generate_blank_mission("caucasus")
        files["l10n/DEFAULT/veaf-config.lua"] = (
            b"veaf.HideNamesFromSpawnedGroups = true\nveaf.silenceAtcOnAllAirbases()\nveafCombatZone.initialize()\n"
        )
        path = tmp_path / "Golan.miz"
        create_miz(path, files)
        return path

    @staticmethod
    def _bridge(miz: Path) -> Path:
        bridge = miz.with_name("dcs-bridge.lua")
        bridge.write_text("-- the bridge\n", encoding="utf-8")
        return bridge

    def test_clear_sky_removes_what_hides_the_ground(self) -> None:
        weather = {
            "clouds": {"preset": "Preset7", "base": 2500, "density": 8, "iprecptns": 1},
            "enable_fog": True,
            "fog": {"thickness": 300, "visibility": 800},
            "enable_dust": True,
            "dust_density": 900,
            "visibility": {"distance": 9000},
            "wind": {"atGround": {"speed": 3}},
        }
        clear = clear_sky(weather)
        assert "preset" not in clear["clouds"]
        assert clear["clouds"]["density"] == 0 and clear["clouds"]["iprecptns"] == 0 and clear["clouds"]["base"] == 2500
        assert clear["enable_fog"] is False and clear["enable_dust"] is False
        assert clear["visibility"] == {"distance": 80000}
        assert clear["wind"] == weather["wind"]
        assert weather["clouds"]["preset"] == "Preset7"  # the original is not modified

    @pytest.mark.parametrize(("value", "seconds"), [("11:30", 41400), ("00:00", 0), ("23:59", 86340)])
    def test_seconds_of_day(self, value: str, seconds: int) -> None:
        assert seconds_of_day(value) == seconds

    @pytest.mark.parametrize("value", ["24:00", "11h30", "11:60", ""])
    def test_a_bad_time_is_refused(self, value: str) -> None:
        with pytest.raises(ValueError):
            seconds_of_day(value)

    def test_the_copy_goes_beside_the_mission(self) -> None:
        assert recon_mission_path(Path("d/Golan.miz")) == Path("d/Golan_RECON.miz")

    def test_the_shooting_mission_is_derived_and_the_original_kept(self, miz: Path) -> None:
        before = miz.read_bytes()
        out = recon_mission_path(miz)
        changes = derive_recon_mission(miz, out, "09:15", self._bridge(miz))
        assert miz.read_bytes() == before
        assert len(changes) == 4
        content = read_miz(out).mission_content or {}
        assert content["start_time"] == 9 * 3600 + 15 * 60
        assert content["weather"]["visibility"] == {"distance": 80000}
        config = read_member(out, "l10n/DEFAULT/veaf-config.lua").decode("utf-8")
        check_lua_syntax(config)
        # after the mission's own settings, which set it back to true when it came first (Open Training, 2026-11-17)
        assert config.index("veaf.HideNamesFromSpawnedGroups = true") < config.index(
            "HideNamesFromSpawnedGroups = false"
        )
        # recon-shoot activates the zones one at a time: the copy leaves them as the mission has them
        assert "ActivateZone(" not in config
        with zipfile.ZipFile(out) as archive:
            assert archive.namelist().count("l10n/DEFAULT/veaf-config.lua") == 1
            # recon-plan and recon-shoot talk to the mission through the bridge
            assert archive.namelist().count("l10n/DEFAULT/dcs-bridge.lua") == 1
        assert "dcs-bridge" in str(content["trig"]["actions"])

    def test_a_mission_without_veaf_is_refused(self, tmp_path: Path) -> None:
        path = tmp_path / "plain.miz"
        create_miz(path, generate_blank_mission("caucasus"))
        with pytest.raises(ValueError, match="veaf-config.lua"):
            derive_recon_mission(path, tmp_path / "out.miz", "11:30", self._bridge(path))

    def test_the_copy_never_overwrites_the_original(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="must not overwrite"):
            derive_recon_mission(miz, miz, "11:30", self._bridge(miz))

    @staticmethod
    def _with_spawn_data(miz: Path, loaded: bool) -> Path:
        """*miz* carrying ``veaf-spawn-data.lua``, loaded by a trigger or not."""
        mission = read_miz(miz)
        if loaded:
            content = mission.mission_content or {}
            content.setdefault("trig", {}).setdefault("actions", {})[1] = (
                'a_do_script_file(getValueResourceByKey("VEAF_MapKey_SpawnData"));'
            )
        write_miz(
            mission, miz, additional_files={"l10n/DEFAULT/veaf-spawn-data.lua": b"veafUnits.GroupsDatabase = {}\n"}
        )
        return miz

    def test_a_spawn_database_no_trigger_loads_is_refused(self, miz: Path, tmp_path: Path) -> None:
        # the Caucasus _RECON copy of 2026-11-17: every #command zone spawned nothing
        self._with_spawn_data(miz, loaded=False)
        with pytest.raises(ValueError, match="VEAF_MapKey_SpawnData"):
            derive_recon_mission(miz, tmp_path / "out.miz", "11:30", self._bridge(miz))
        with pytest.raises(ValueError, match="VEAF_MapKey_SpawnData"):
            derive_check_mission(miz, tmp_path / "check.miz", self._bridge(miz))

    def test_a_spawn_database_a_trigger_loads_is_accepted(self, miz: Path, tmp_path: Path) -> None:
        self._with_spawn_data(miz, loaded=True)
        derive_recon_mission(miz, tmp_path / "out.miz", "11:30", self._bridge(miz))
        derive_check_mission(miz, tmp_path / "check.miz", self._bridge(miz))
