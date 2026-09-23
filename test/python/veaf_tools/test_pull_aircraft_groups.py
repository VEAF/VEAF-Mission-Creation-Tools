"""A mission maker can take the new shipped entries, one by one, without losing his own.

FEAT-DEFAULTS-CATALOGUE-FLOW ticket 03. Once a mission folder owns a catalogue it stands alone —
nothing is merged into it behind the maker's back. `pull-aircraft-groups` is the explicit gesture
that closes the loop: *"il faut un moyen pour le Mission Maker de reprendre les nouveaux defaults —
mais de manière sélective, pas brutalement tous les defaults."*

The line that must never move: an entry the maker already has is **never** replaced, even when the
shipped one differs. His F-14 loadout stays his.
"""

from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import veaf_tools.commands  # noqa: F401  — side effect: registers all commands on `app`
import yaml
from typer.testing import CliRunner
from veaf_tools.app import app

_runner = CliRunner()

_DYNAMIC = "src/dynamic-slot-templates.yaml"
_SPAWNABLES = "src/spawnables.yaml"


def _catalogue(*names: str, payload: str = "shipped") -> str:
    return yaml.safe_dump(
        {
            "airplanes": {
                "coalitions": {"blue": {"CJTF Blue": {name: {"name": name, "origin": payload} for name in names}}}
            }
        }
    )


class _Folder:
    """A mission folder carrying its own catalogues and a shipped one under `published/`."""

    def __init__(self, tmp: str, mine: str | None, shipped: str, spawnables_shipped: str | None = None) -> None:
        self.path = Path(tmp)
        shipped_dir = self.path / "published" / "src" / "defaults" / "mission-folder" / "src"
        shipped_dir.mkdir(parents=True)
        (shipped_dir / "dynamic-slot-templates.yaml").write_text(shipped, encoding="utf-8")
        (shipped_dir / "spawnables.yaml").write_text(spawnables_shipped or _catalogue("veafSpawn-Shipped"), "utf-8")
        (self.path / "src").mkdir()
        self.local = self.path / _DYNAMIC
        if mine is not None:
            self.local.write_text(mine, encoding="utf-8")

    def run(self, *args: str) -> object:
        return _runner.invoke(app, ["pull-aircraft-groups", str(self.path), "--kind", "dynamic-template", *args])

    def groups(self) -> dict:
        parsed = yaml.safe_load(self.local.read_text(encoding="utf-8")) or {}
        return parsed["airplanes"]["coalitions"]["blue"]["CJTF Blue"]


class TestTheReportIsReadOnly(unittest.TestCase):
    def test_it_names_what_the_shipped_catalogue_has_and_the_mission_does_not(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(
                tmp, _catalogue("A-10C II Template", payload="mine"), _catalogue("A-10C II Template", "F-14BU Template")
            )
            result = folder.run()
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertIn("F-14BU Template", result.output)
            self.assertEqual(sorted(folder.groups()), ["A-10C II Template"], "the report must write nothing")

    def test_it_says_the_shared_entries_are_kept(self) -> None:
        """An entry present on both sides is reported as kept, not hidden."""
        with TemporaryDirectory() as tmp:
            folder = _Folder(
                tmp, _catalogue("A-10C II Template", payload="mine"), _catalogue("A-10C II Template", "F-14BU Template")
            )
            result = folder.run("--verbose")
        self.assertIn("A-10C II Template", result.output)

    def test_a_folder_that_is_up_to_date_says_so(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, _catalogue("A-10C II Template"), _catalogue("A-10C II Template"))
            result = folder.run()
        self.assertEqual(result.exit_code, 0, result.output)
        self.assertIn("0", result.output)


class TestAddTakesOnlyWhatIsNamed(unittest.TestCase):
    def test_one_name_brings_in_one_entry(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(
                tmp, _catalogue("A-10C II Template", payload="mine"), _catalogue("F-14BU Template", "F-16C Template")
            )
            result = folder.run("--add", "F-16C Template")
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertEqual(sorted(folder.groups()), ["A-10C II Template", "F-16C Template"])

    def test_an_unknown_name_is_an_error_and_writes_nothing(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, _catalogue("A-10C II Template", payload="mine"), _catalogue("F-14BU Template"))
            before = folder.local.read_text(encoding="utf-8")
            result = folder.run("--add", "Nonexistent Template")
            self.assertEqual(result.exit_code, 1)
            self.assertIn("Nonexistent Template", result.output)
            self.assertEqual(folder.local.read_text(encoding="utf-8"), before)

    def test_a_name_the_maker_already_owns_leaves_his_version_alone(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, _catalogue("A-10C II Template", payload="mine"), _catalogue("A-10C II Template"))
            result = folder.run("--add", "A-10C II Template")
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertEqual(folder.groups()["A-10C II Template"]["origin"], "mine")


class TestAddNewTakesEverythingMissing(unittest.TestCase):
    def test_every_missing_entry_arrives(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, _catalogue("Mine", payload="mine"), _catalogue("One", "Two", "Three"))
            result = folder.run("--add-new")
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertEqual(sorted(folder.groups()), ["Mine", "One", "Three", "Two"])

    def test_an_entry_the_maker_edited_is_untouched(self) -> None:
        """The whole decision in one assertion: same name, different content, his wins."""
        with TemporaryDirectory() as tmp:
            folder = _Folder(
                tmp, _catalogue("A-10C II Template", payload="mine"), _catalogue("A-10C II Template", "New")
            )
            folder.run("--add-new")
            self.assertEqual(folder.groups()["A-10C II Template"]["origin"], "mine")
            self.assertEqual(folder.groups()["New"]["origin"], "shipped")

    def test_an_entry_deleted_on_purpose_stays_deleted_without_a_flag(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, _catalogue("Mine", payload="mine"), _catalogue("Mine", "Deliberately Removed"))
            folder.run()
            self.assertEqual(sorted(folder.groups()), ["Mine"])

    def test_an_empty_local_catalogue_takes_the_whole_shipped_one(self) -> None:
        skeleton = "airplanes:\n  coalitions: {}\nhelicopters:\n  coalitions: {}\n"
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, skeleton, _catalogue("One", "Two"))
            result = folder.run("--add-new")
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertEqual(sorted(folder.groups()), ["One", "Two"])

    def test_no_local_file_at_all_is_created_by_the_pull(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, None, _catalogue("One"))
            self.assertFalse(folder.local.exists())
            result = folder.run("--add-new")
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertEqual(sorted(folder.groups()), ["One"])


class TestBothFamilies(unittest.TestCase):
    def test_a_name_living_in_the_other_family_is_not_an_unknown_name(self) -> None:
        """`--kind both` looks a name up across both catalogues before calling it unknown."""
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, _catalogue("Mine", payload="mine"), _catalogue("Dyn Only"))
            result = _runner.invoke(app, ["pull-aircraft-groups", str(folder.path), "--add", "veafSpawn-Shipped"])
            self.assertEqual(result.exit_code, 0, result.output)
            spawnables = yaml.safe_load((folder.path / _SPAWNABLES).read_text(encoding="utf-8"))
            self.assertIn("veafSpawn-Shipped", spawnables["airplanes"]["coalitions"]["blue"]["CJTF Blue"])
            self.assertEqual(sorted(folder.groups()), ["Mine"], "the other family must not move")

    def test_an_invalid_kind_is_refused(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, _catalogue("Mine"), _catalogue("One"))
            result = _runner.invoke(app, ["pull-aircraft-groups", str(folder.path), "--kind", "nonsense"])
        self.assertNotEqual(result.exit_code, 0)


class TestABrokenLocalCatalogue(unittest.TestCase):
    """Measured before the guard: 118 bytes of hand-tuned catalogue, one unterminated quote, and
    `--add-new` wrote 371 420 bytes of shipped entries over it. Empty and unreadable are not the
    same answer."""

    #: The shape the measurement used: a hand edit that left a quote unterminated.
    BROKEN = 'airplanes:\n  coalitions:\n    blue:\n      CJTF Blue:\n        "My Hand Tuned F-14: {\n'

    def test_add_new_refuses_and_writes_nothing(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, self.BROKEN, _catalogue("One", "Two"))
            result = folder.run("--add-new")
            self.assertEqual(result.exit_code, 1)
            self.assertEqual(folder.local.read_text(encoding="utf-8"), self.BROKEN)

    def test_even_the_read_only_report_says_so_rather_than_counting_zero(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = _Folder(tmp, self.BROKEN, _catalogue("One"))
            result = folder.run()
            self.assertEqual(result.exit_code, 1)
            self.assertIn("dynamic-slot-templates.yaml", result.output)


class TestWithoutAShippedCatalogue(unittest.TestCase):
    def test_it_says_so_rather_than_failing_silently(self) -> None:
        with TemporaryDirectory() as tmp:
            folder = Path(tmp) / "mission"
            (folder / "src").mkdir(parents=True)
            (folder / _DYNAMIC).write_text(_catalogue("Mine"), encoding="utf-8")
            # No `published/`, and the dev checkout answers instead — so the shipped catalogue is
            # the real 128-template one. That is the honest end-to-end shape of this command.
            result = _runner.invoke(app, ["pull-aircraft-groups", str(folder), "--kind", "dynamic-template"])
        self.assertEqual(result.exit_code, 0, result.output)
        self.assertIn("Template", result.output)


if __name__ == "__main__":
    unittest.main()
