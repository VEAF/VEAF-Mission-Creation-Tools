"""Tests for mission_builder.third_party_mods."""

from mission_builder.third_party_mods import default_third_party_mods, strip_third_party_mods


def _mission(required: dict | None) -> dict:
    content: dict = {"date": {}, "result": {}}
    if required is not None:
        content["requiredModules"] = required
    return content


class TestDefaultList:
    def test_bundled_default_includes_the_v5_hack_mods(self) -> None:
        mods = default_third_party_mods()

        assert {"Hercules", "UH-60L", "A-4E-C", "T-45", "AM2", "Bronco-OV-10A"} <= mods
        assert "FlankerEx by Codename Flanker" in mods


class TestStripThirdPartyMods:
    def test_removes_default_mods_and_keeps_unlisted_ones(self) -> None:
        mission = _mission({"Hercules": "Hercules", "F-16C": "F-16C"})

        removed = strip_third_party_mods(mission)

        assert removed == ["Hercules"]
        assert mission["requiredModules"] == {"F-16C": "F-16C"}

    def test_extra_mods_union_with_the_default_list(self) -> None:
        mission = _mission({"Hercules": "Hercules", "MyMod": "MyMod", "F-16C": "F-16C"})

        removed = strip_third_party_mods(mission, extra_mods=["MyMod"])

        assert removed == ["Hercules", "MyMod"]
        assert mission["requiredModules"] == {"F-16C": "F-16C"}

    def test_extra_mods_do_not_replace_the_default_list(self) -> None:
        mission = _mission({"Hercules": "Hercules"})

        removed = strip_third_party_mods(mission, extra_mods=["OnlyThis"])

        # Hercules (a default) is still stripped even though extra_mods lists something else.
        assert removed == ["Hercules"]

    def test_no_op_when_required_modules_is_absent(self) -> None:
        mission = _mission(None)

        assert strip_third_party_mods(mission) == []
        assert "requiredModules" not in mission

    def test_no_op_when_required_modules_is_empty(self) -> None:
        mission = _mission({})

        assert strip_third_party_mods(mission) == []
        assert mission["requiredModules"] == {}

    def test_no_op_when_required_modules_is_not_a_dict(self) -> None:
        mission = _mission(None)
        mission["requiredModules"] = []

        assert strip_third_party_mods(mission) == []

    def test_returns_removed_ids_sorted(self) -> None:
        mission = _mission({"UH-60L": "UH-60L", "A-4E-C": "A-4E-C", "Hercules": "Hercules"})

        removed = strip_third_party_mods(mission)

        assert removed == ["A-4E-C", "Hercules", "UH-60L"]
