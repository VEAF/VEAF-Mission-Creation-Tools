"""Tests for MissionExtractorWorker.__init__ — path validation."""

from __future__ import annotations

import tempfile
import unittest
import zipfile
from pathlib import Path

MINIMAL_MISSION_LUA = b'mission = {\n  ["name"] = "TestMission",\n}\n'
MINIMAL_OPTIONS_LUA = b"options = {\n}\n"
MINIMAL_WAREHOUSES_LUA = b"warehouses = {\n}\n"


class TestMissionExtractorWorkerInit(unittest.TestCase):
    def test_valid_inputs_init_succeeds(self) -> None:
        from mission_extractor.mission_extractor_worker import MissionExtractorWorker

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            miz = folder / "test.miz"
            miz.write_bytes(b"PK\x03\x04")
            worker = MissionExtractorWorker(mission_folder=folder, input_mission_path=miz)
            self.assertEqual(worker.input_mission_path, miz)
            self.assertEqual(worker.mission_folder, folder)

    def test_missing_mission_file_raises(self) -> None:
        from mission_extractor.mission_extractor_worker import MissionExtractorWorker

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            missing = folder / "nonexistent.miz"
            with self.assertRaises((FileNotFoundError, SystemExit)):
                MissionExtractorWorker(mission_folder=folder, input_mission_path=missing)

    def test_missing_mission_folder_raises(self) -> None:
        from mission_extractor.mission_extractor_worker import MissionExtractorWorker

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            miz = folder / "test.miz"
            miz.write_bytes(b"PK\x03\x04")
            nonexistent_folder = folder / "no_such_folder"
            with self.assertRaises((FileNotFoundError, SystemExit)):
                MissionExtractorWorker(mission_folder=nonexistent_folder, input_mission_path=miz)


class TestMissionExtractorWorkerExtract(unittest.TestCase):
    def test_extract_handles_community_script_dicts(self) -> None:
        """Regression: get_community_script_files() returns dicts, not tuples.

        extract_mission used to index entries as f[0]/f[1], raising KeyError on
        the dict entries. It must iterate them by their 'path'/'dest' keys and
        remove the bundled community scripts from the extracted mission.
        """
        from mission_extractor.mission_extractor_worker import MissionExtractorWorker
        from mission_tools import get_community_script_files

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            miz = folder / "test.miz"

            community = get_community_script_files()
            with zipfile.ZipFile(miz, "w") as zf:
                zf.writestr("mission", MINIMAL_MISSION_LUA)
                zf.writestr("options", MINIMAL_OPTIONS_LUA)
                zf.writestr("warehouses", MINIMAL_WAREHOUSES_LUA)
                zf.writestr("theatre", b"Caucasus")
                zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
                zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
                # Bundle one community script so the cleanup loop has something to remove.
                first = community[0]
                bundled_name = Path(first["path"]).name
                zf.writestr(f"{first['dest']}/{bundled_name}", b"-- community script\n")

            worker = MissionExtractorWorker(mission_folder=folder, input_mission_path=miz)
            worker.extract_mission()  # must not raise KeyError

            extracted = folder / "src" / "mission" / first["dest"] / bundled_name
            self.assertFalse(extracted.exists(), "community script should have been removed on extract")


class TestMissionExtractorRefresh(unittest.TestCase):
    """`refresh=True` overwrites existing scripts instead of keeping the old copy (FOOTHOLD-V6-005)."""

    def _miz_with_script(self, miz: Path, script_name: str, script_body: bytes) -> None:
        with zipfile.ZipFile(miz, "w") as zf:
            zf.writestr("mission", MINIMAL_MISSION_LUA)
            zf.writestr("options", MINIMAL_OPTIONS_LUA)
            zf.writestr("warehouses", MINIMAL_WAREHOUSES_LUA)
            zf.writestr("theatre", b"Caucasus")
            zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
            zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
            zf.writestr(f"l10n/DEFAULT/{script_name}", script_body)

    def test_default_keeps_existing_script(self) -> None:
        from mission_extractor.mission_extractor_worker import MissionExtractorWorker

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            (folder / "src" / "scripts").mkdir(parents=True)
            (folder / "src" / "scripts" / "Engine.lua").write_text("-- OLD\n", encoding="utf-8")
            miz = folder / "test.miz"
            self._miz_with_script(miz, "Engine.lua", b"-- NEW\n")

            MissionExtractorWorker(mission_folder=folder, input_mission_path=miz).extract_mission()

            self.assertEqual((folder / "src" / "scripts" / "Engine.lua").read_text(encoding="utf-8"), "-- OLD\n")

    def test_refresh_overwrites_existing_script(self) -> None:
        from mission_extractor.mission_extractor_worker import MissionExtractorWorker

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            (folder / "src" / "scripts").mkdir(parents=True)
            (folder / "src" / "scripts" / "Engine.lua").write_text("-- OLD\n", encoding="utf-8")
            miz = folder / "test.miz"
            self._miz_with_script(miz, "Engine.lua", b"-- NEW\n")

            MissionExtractorWorker(mission_folder=folder, input_mission_path=miz, refresh=True).extract_mission()

            self.assertEqual((folder / "src" / "scripts" / "Engine.lua").read_text(encoding="utf-8"), "-- NEW\n")


class TestMissionExtractorGeneratedArtifacts(unittest.TestCase):
    """The build's own injected Lua must not come back as a mission source.

    FIX-EXTRACT-GENERATED-ARTIFACTS-01: extraction moved every remaining
    ``l10n/DEFAULT/*.lua`` into ``src/scripts/``, including the files the build
    injects through a ``VEAF_MapKey_*`` map resource (``veaf-spawn-data.lua``,
    ``dcs-bridge.lua``). The next build then embedded that stale copy alongside
    the freshly injected one.
    """

    def _miz(self, miz: Path, scripts: dict[str, bytes], map_resource: dict[str, str]) -> None:
        entries = "".join(f'    ["{key}"] = "{value}",\n' for key, value in map_resource.items())
        with zipfile.ZipFile(miz, "w") as zf:
            zf.writestr("mission", MINIMAL_MISSION_LUA)
            zf.writestr("options", MINIMAL_OPTIONS_LUA)
            zf.writestr("warehouses", MINIMAL_WAREHOUSES_LUA)
            zf.writestr("theatre", b"Caucasus")
            zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
            zf.writestr("l10n/DEFAULT/mapResource", f"mapResource = {{\n{entries}}}\n".encode())
            for name, body in scripts.items():
                zf.writestr(f"l10n/DEFAULT/{name}", body)

    def _extract(self, folder: Path, scripts: dict[str, bytes], map_resource: dict[str, str]) -> None:
        from mission_extractor.mission_extractor_worker import MissionExtractorWorker

        miz = folder / "test.miz"
        self._miz(miz, scripts, map_resource)
        MissionExtractorWorker(mission_folder=folder, input_mission_path=miz).extract_mission()

    def test_spawn_data_is_not_extracted(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            self._extract(
                folder,
                {"veaf-spawn-data.lua": b"-- generated\n"},
                {"VEAF_MapKey_SpawnData": "veaf-spawn-data.lua"},
            )

            self.assertFalse((folder / "src" / "scripts" / "veaf-spawn-data.lua").exists())
            # …and not in src/mission/ either, which is what feeds the next build.
            self.assertFalse((folder / "src" / "mission" / "l10n" / "DEFAULT" / "veaf-spawn-data.lua").exists())

    def test_dcs_bridge_is_not_extracted(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            self._extract(
                folder,
                {"dcs-bridge.lua": b"-- generated\n"},
                {"VEAF_MapKey_DcsBridge": "dcs-bridge.lua"},
            )

            self.assertFalse((folder / "src" / "scripts" / "dcs-bridge.lua").exists())

    def test_artifact_without_its_map_key_is_still_stripped(self) -> None:
        """A mission whose mapResource was rewritten still must not get the file back."""
        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            self._extract(folder, {"veaf-spawn-data.lua": b"-- generated\n"}, {})

            self.assertFalse((folder / "src" / "scripts" / "veaf-spawn-data.lua").exists())

    def test_script_named_by_a_foreign_map_key_is_extracted(self) -> None:
        """We strip our own output, not a mission maker's script."""
        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            self._extract(
                folder,
                {"Engine.lua": b"-- theirs\n"},
                {"ResKey_Action_1": "Engine.lua"},
            )

            self.assertTrue((folder / "src" / "scripts" / "Engine.lua").exists())

    def test_unreferenced_script_is_extracted(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            self._extract(folder, {"Engine.lua": b"-- theirs\n"}, {})

            self.assertTrue((folder / "src" / "scripts" / "Engine.lua").exists())

    def test_veaf_map_key_pointing_at_a_lua_file_is_stripped_by_the_map_resource(self) -> None:
        """Data-driven, so an artifact added later needs no edit here."""
        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            self._extract(
                folder,
                {"veaf-future-thing.lua": b"-- generated\n"},
                {"VEAF_MapKey_FutureThing": "veaf-future-thing.lua"},
            )

            self.assertFalse((folder / "src" / "scripts" / "veaf-future-thing.lua").exists())


if __name__ == "__main__":
    unittest.main()
