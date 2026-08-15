"""`veaf-tools convert-other` accepts a release `.zip` as well as a `.miz`.

Lekaa ships Foothold as a zip bundling the mission with a config manager and a manual
(FEAT-FOOTHOLD-RELEASE-INTAKE-002); the command must adopt the `.miz` it holds, and refuse
to guess when the archive is ambiguous.
"""

from __future__ import annotations

import unittest
import zipfile
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

import veaf_tools.commands  # noqa: F401 — registers commands on `app`
from mission_builder.v5_converter import ConversionReport
from typer.testing import CliRunner
from veaf_tools.app import app

_runner = CliRunner()


def _zip(path: Path, members: dict[str, bytes]) -> Path:
    with zipfile.ZipFile(path, "w") as zf:
        for name, payload in members.items():
            zf.writestr(name, payload)
    return path


class TestConvertOtherInput(unittest.TestCase):
    def _invoke(self, input_path: Path, out: Path):  # type: ignore[no-untyped-def]
        """Run the command with the conversion itself stubbed out, returning (result, mock).

        The real converter creates the output folder; the stub does not, so create it here
        or the command fails writing its report.
        """
        out.mkdir(parents=True, exist_ok=True)
        with mock.patch("veaf_tools.commands.convert_other.OtherMissionConverter") as converter_cls:
            converter_cls.return_value.convert.return_value = ConversionReport(mission_folder=out, version="test")
            result = _runner.invoke(app, ["convert-other", str(input_path), str(out)])
        return result, converter_cls.return_value.convert

    def test_adopts_the_miz_held_in_an_archive(self) -> None:
        with TemporaryDirectory() as td:
            archive = _zip(
                Path(td) / "Foothold_CA_4.4.1.zip",
                {"Foothold_CA_4.4.1.miz": b"mission", "Foothold Config Manager 1.8.5.exe": b"exe"},
            )
            result, convert = self._invoke(archive, Path(td) / "out")

            self.assertEqual(result.exit_code, 0, result.output)
            adopted = convert.call_args.kwargs["input_mission_path"]
            # The extracted .miz was passed on — not the archive itself.
            self.assertEqual(adopted.name, "Foothold_CA_4.4.1.miz")

    def test_reports_which_miz_came_out_of_the_archive(self) -> None:
        with TemporaryDirectory() as td:
            archive = _zip(Path(td) / "release.zip", {"mission.miz": b"m"})
            result, _ = self._invoke(archive, Path(td) / "out")

            self.assertEqual(result.exit_code, 0, result.output)
            self.assertIn("mission.miz", result.output)
            self.assertIn("release.zip", result.output)

    def test_plain_miz_is_passed_straight_through(self) -> None:
        with TemporaryDirectory() as td:
            miz = Path(td) / "mission.miz"
            miz.write_bytes(b"m")
            result, convert = self._invoke(miz, Path(td) / "out")

            self.assertEqual(result.exit_code, 0, result.output)
            # Compared **resolved**: the command puts its input through `resolve_path`, which returns
            # an absolute, resolved path. On a machine whose TEMP is an 8.3 short name
            # (`C:\Users\DPIERR~1\...`) that expands to the long form, so the two Paths differ by
            # form alone and this assertion failed while the command was behaving correctly. CI never
            # saw it, its temp directory already being a long path.
            self.assertEqual(convert.call_args.kwargs["input_mission_path"], miz.resolve())

    def test_archive_without_a_miz_fails_without_converting(self) -> None:
        with TemporaryDirectory() as td:
            archive = _zip(Path(td) / "release.zip", {"README.txt": b"t"})
            result, convert = self._invoke(archive, Path(td) / "out")

            self.assertNotEqual(result.exit_code, 0)
            convert.assert_not_called()

    def test_ambiguous_archive_fails_and_names_the_candidates(self) -> None:
        with TemporaryDirectory() as td:
            archive = _zip(Path(td) / "release.zip", {"alpha.miz": b"a", "bravo.miz": b"b"})
            result, convert = self._invoke(archive, Path(td) / "out")

            self.assertNotEqual(result.exit_code, 0)
            convert.assert_not_called()
            self.assertIn("alpha.miz", result.output)
            self.assertIn("bravo.miz", result.output)


if __name__ == "__main__":
    unittest.main()
