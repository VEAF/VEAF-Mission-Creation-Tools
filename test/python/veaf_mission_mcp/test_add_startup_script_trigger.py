import zipfile
from pathlib import Path
from typing import Any

import pytest
from veaf_mission_mcp.add_startup_script_trigger import add_startup_script_trigger, apply_startup_script_trigger


def _content() -> dict[str, Any]:
    """A minimal mission table with a couple of pre-existing triggers (indices 1, 2)."""
    return {
        "trigrules": {1: {"comment": "existing"}, 2: {"comment": "existing"}},
        "trig": {"actions": {1: "x", 2: "y"}, "conditions": {1: "z", 2: "w"}},
    }


# ---------------------------------------------------------------------------
# Pure mutation (in-memory) — fine-grained structure assertions
# ---------------------------------------------------------------------------


class TestInlineMode:
    def test_builds_a_do_script_trigger(self) -> None:
        content = _content()

        index, extra = apply_startup_script_trigger(
            content, mode="inline", comment="hello", inline_lua='env.info("hi")'
        )

        rule = content["trigrules"][index]
        assert rule["predicate"] == "triggerStart"
        assert rule["actions"][0] == {"predicate": "a_do_script", "text": 'env.info("hi")'}
        assert content["trig"]["actions"][index] == 'a_do_script("env.info(\\"hi\\")");'
        assert content["trig"]["conditions"][index] == "return true"
        assert content["trig"]["flag"][index] is True
        assert content["trig"]["funcStartup"][index] == (
            f"if mission.trig.conditions[{index}]() then mission.trig.actions[{index}]() end"
        )
        assert extra == {}

    def test_appends_past_existing_triggers_without_renumbering(self) -> None:
        content = _content()

        index, _ = apply_startup_script_trigger(content, mode="inline", comment="x", inline_lua="return")

        assert index == 3  # max existing (2) + 1
        assert content["trigrules"][1] == {"comment": "existing"}  # untouched
        assert content["trigrules"][2] == {"comment": "existing"}

    def test_inline_requires_lua(self) -> None:
        with pytest.raises(ValueError, match="requires inline_lua"):
            apply_startup_script_trigger(_content(), mode="inline", comment="x")


class TestFileStaticMode:
    def test_registers_resource_and_returns_bytes(self, tmp_path: Path) -> None:
        script = tmp_path / "myscript.lua"
        script.write_bytes(b"-- my script\n")
        content = _content()
        map_resource: dict[str, str] = {}

        index, extra = apply_startup_script_trigger(
            content, mode="file_static", comment="load", source_path=str(script), map_resource=map_resource
        )

        key = content["trigrules"][index]["actions"][0]["file"]
        # The key belongs to the mission's `l10n/DEFAULT/mapResource` table — NOT to the
        # `mission` table: DCS resolves getValueResourceByKey against the former only.
        assert map_resource[key] == "myscript.lua"
        assert "mapResource" not in content
        assert content["trig"]["actions"][index] == f'a_do_script_file(getValueResourceByKey("{key}"));'
        assert extra == {"l10n/DEFAULT/myscript.lua": b"-- my script\n"}

    def test_requires_the_map_resource_table(self, tmp_path: Path) -> None:
        """Without the mission's mapResource table the key would be lost — fail loudly."""
        script = tmp_path / "myscript.lua"
        script.write_text("-- x\n", encoding="utf-8")
        with pytest.raises(ValueError, match="requires map_resource"):
            apply_startup_script_trigger(_content(), mode="file_static", comment="load", source_path=str(script))

    def test_two_same_named_files_get_distinct_keys(self, tmp_path: Path) -> None:
        script = tmp_path / "dup.lua"
        script.write_text("-- 1\n", encoding="utf-8")
        content = _content()

        map_resource: dict[str, str] = {}
        i1, _ = apply_startup_script_trigger(
            content, mode="file_static", comment="a", source_path=str(script), map_resource=map_resource
        )
        i2, _ = apply_startup_script_trigger(
            content, mode="file_static", comment="b", source_path=str(script), map_resource=map_resource
        )

        k1 = content["trigrules"][i1]["actions"][0]["file"]
        k2 = content["trigrules"][i2]["actions"][0]["file"]
        assert k1 != k2

    def test_missing_source_file_raises(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            apply_startup_script_trigger(
                _content(), mode="file_static", comment="x", source_path=str(tmp_path / "nope.lua")
            )


class TestFileDynamicMode:
    def test_loads_from_runtime_path(self) -> None:
        content = _content()

        index, extra = apply_startup_script_trigger(
            content, mode="file_dynamic", comment="dyn", runtime_path="C:/scripts/x.lua"
        )

        assert content["trigrules"][index]["actions"][0]["predicate"] == "a_do_script"
        assert "loadfile([[C:/scripts/x.lua]])" in content["trig"]["actions"][index]
        assert extra == {}

    def test_dynamic_requires_runtime_path(self) -> None:
        with pytest.raises(ValueError, match="requires runtime_path"):
            apply_startup_script_trigger(_content(), mode="file_dynamic", comment="x")


class TestUnknownMode:
    def test_raises(self) -> None:
        with pytest.raises(ValueError, match="Unknown mode"):
            apply_startup_script_trigger(_content(), mode="bogus", comment="x")

    def test_first_trigger_when_no_existing(self) -> None:
        index, _ = apply_startup_script_trigger({}, mode="inline", comment="x", inline_lua="return")
        assert index == 1


# ---------------------------------------------------------------------------
# I/O path (through the .miz) — light integration
# ---------------------------------------------------------------------------


class TestMizIntegration:
    def test_inline_writes_and_backs_up(self, sample_miz: Path) -> None:
        assert list(sample_miz.parent.glob("mission.*.miz")) == []

        result = add_startup_script_trigger(sample_miz, mode="inline", comment="x", inline_lua="return")

        assert result["trigger_index"] >= 1
        assert len(list(sample_miz.parent.glob("mission.*.miz"))) == 1

    def test_static_embeds_the_file_in_the_archive(self, sample_miz: Path, tmp_path: Path) -> None:
        script = tmp_path / "myscript.lua"
        script.write_text("-- my script\n", encoding="utf-8")

        add_startup_script_trigger(sample_miz, mode="file_static", comment="load", source_path=str(script))

        with zipfile.ZipFile(sample_miz) as zf:
            assert "l10n/DEFAULT/myscript.lua" in zf.namelist()
            # Regression guard: the resource key must land in l10n/DEFAULT/mapResource, the
            # only table DCS resolves. Writing it into `mission` leaves the editor's FILE
            # field empty and the script never loads.
            mission_txt = zf.read("mission").decode("utf-8")
            map_resource_txt = zf.read("l10n/DEFAULT/mapResource").decode("utf-8")
        key = mission_txt.split('getValueResourceByKey(\\"', 1)[1].split('\\"', 1)[0]
        assert key in map_resource_txt
        assert "myscript.lua" in map_resource_txt

    def test_static_writes_map_resource_when_the_member_is_absent(self, tmp_path: Path) -> None:
        """A .miz with no l10n/DEFAULT/mapResource still gets one (write_miz only rewrites
        members that already exist, so the key would otherwise be silently dropped)."""
        script = tmp_path / "s.lua"
        script.write_text("-- x\n", encoding="utf-8")
        miz = tmp_path / "bare.miz"
        with zipfile.ZipFile(miz, "w") as zf:
            zf.writestr("mission", 'mission = \n{\n    ["trig"] = \n    {\n    },\n}\n')

        add_startup_script_trigger(miz, mode="file_static", comment="load", source_path=str(script))

        with zipfile.ZipFile(miz) as zf:
            assert "l10n/DEFAULT/mapResource" in zf.namelist()
            assert "s.lua" in zf.read("l10n/DEFAULT/mapResource").decode("utf-8")

    def test_raises_when_mission_file_is_missing(self, tmp_path: Path) -> None:
        miz = tmp_path / "empty.miz"
        with zipfile.ZipFile(miz, "w") as zf:
            zf.writestr("options", b"options = {\n}\n")
        with pytest.raises(ValueError, match="Not a valid DCS mission archive"):
            add_startup_script_trigger(miz, mode="inline", comment="x", inline_lua="return")
