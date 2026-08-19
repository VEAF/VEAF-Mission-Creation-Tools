from pathlib import Path

import pytest
from veaf_mission_mcp.add_trigger_zone import add_trigger_zone
from veaf_mission_mcp.describe_mission import describe_mission


class TestAddTriggerZone:
    def test_adds_a_zone_visible_after_reload(self, sample_miz: Path) -> None:
        add_trigger_zone(sample_miz, name="CZ_North", position={"x": 100.0, "y": 200.0}, radius=3000)

        zones = {z["name"] for z in describe_mission(sample_miz)["zones"]}
        assert "CZ_North" in zones

    def test_zone_carries_position_and_radius(self, sample_miz: Path) -> None:
        add_trigger_zone(sample_miz, name="CZ_Pos", position={"x": 1500.0, "y": 2500.0}, radius=4200)

        zone = next(z for z in describe_mission(sample_miz)["zones"] if z["name"] == "CZ_Pos")
        assert (zone["x"], zone["y"], zone["radius"]) == (1500.0, 2500.0, 4200)

    def test_fresh_zone_id_past_existing_ones(self, sample_miz: Path) -> None:
        # sample_miz already has combatZone_Test (no explicit zoneId → treated as 0).
        first = add_trigger_zone(sample_miz, name="Z1", position={"x": 0.0, "y": 0.0}, radius=100)
        second = add_trigger_zone(sample_miz, name="Z2", position={"x": 0.0, "y": 0.0}, radius=100)

        assert second["zone_id"] == first["zone_id"] + 1

    def test_backs_up_before_write(self, sample_miz: Path) -> None:
        assert list(sample_miz.parent.glob("mission.*.miz")) == []

        add_trigger_zone(sample_miz, name="Z", position={"x": 0.0, "y": 0.0}, radius=100)

        assert len(list(sample_miz.parent.glob("mission.*.miz"))) == 1

    def test_calling_twice_creates_two_zones(self, sample_miz: Path) -> None:
        add_trigger_zone(sample_miz, name="Dup", position={"x": 0.0, "y": 0.0}, radius=100)
        add_trigger_zone(sample_miz, name="Dup", position={"x": 0.0, "y": 0.0}, radius=100)

        matching = [z for z in describe_mission(sample_miz)["zones"] if z["name"] == "Dup"]
        assert len(matching) == 2

    def test_raises_when_mission_file_is_missing(self, tmp_path: Path) -> None:
        import zipfile

        miz = tmp_path / "empty.miz"
        with zipfile.ZipFile(miz, "w") as zf:
            zf.writestr("options", b"options = {\n}\n")

        # "archive" left the message when the action started accepting a mission folder too.
        with pytest.raises(ValueError, match="Not a valid DCS mission"):
            add_trigger_zone(miz, name="Z", position={"x": 0.0, "y": 0.0}, radius=100)
