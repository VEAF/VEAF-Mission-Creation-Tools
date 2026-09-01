"""End-to-end: `prepare --theatre` → `build` → `extract` → `validate` (FIX-PREPARE-THEATRE-COALITIONS).

A mission scaffolded from nothing by ``prepare --template minimal --theatre <map>`` and then built
used to come out unloadable: the shipped ``src/spawnables.yaml`` / ``src/dynamic-slot-templates.yaml``
put groups under ``coalition.<side>.country`` and the coalition placeholder added one more country,
while ``coalitions.<side>`` — the list of country ids assigned to a side — stayed the empty
``{}`` the blank mission generates. DCS then opens the CHANGING COALITIONS screen and refuses the
mission.

The defect lives in the **seam** between two commands: the generator is right on its own (a mission
with no unit needs no assigned country) and each injector is right on its own (it writes a valid
country entry). Only running the chain shows it, which is why a test of either half missed it — and
did. So this test drives the real CLI commands end to end.

The build needs the Lua corpus it packages; the content is irrelevant here, so a stub scripts root
stands in for it (see :meth:`_stub_scripts_root`) and keeps the test independent of a built
``veaf-scripts.lua`` artifact.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import luadata
import veaf_tools.commands  # noqa: F401  — side effect: registers every command on `app`
from mission_tools.mission_constants import get_community_script_files
from typer.testing import CliRunner
from veaf_libs.mission_table import CATEGORIES, indexed
from veaf_libs.mission_validator import ERROR, validate_mission_folder
from veaf_tools.app import app

#: The theatre the tutorial walks a newcomer through.
_THEATRE = "Caucasus"


def _country_ids_holding_units(side_content: dict) -> set[int]:
    """Return the ids of the countries that own at least one group on this side.

    Args:
        side_content: One ``mission.coalition.<side>`` table.

    Returns:
        The DCS country ids owning groups, as ints.
    """
    ids: set[int] = set()
    for country in indexed(side_content.get("country")):
        if not isinstance(country, dict) or country.get("id") is None:
            continue
        if any(indexed((country.get(category) or {}).get("group")) for category in CATEGORIES):
            ids.add(int(country["id"]))
    return ids


class TestPrepareTheatreBuildValidate(unittest.TestCase):
    """The documented from-scratch path must produce a mission DCS can load."""

    def setUp(self) -> None:
        self.runner = CliRunner()
        # The CLI callback phones home for a version check; nothing here needs the network.
        patcher = patch("veaf_libs.user_config.get_check_updates", return_value=False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def _run(self, *args: str) -> None:
        """Invoke one CLI command and fail the test with its output if it aborts."""
        result = self.runner.invoke(app, list(args))
        self.assertEqual(result.exit_code, 0, f"`{' '.join(args)}` failed:\n{result.output}")

    def _stub_scripts_root(self, root: Path) -> Path:
        """Create a scripts root holding an empty stand-in for every Lua file the build packages.

        The build refuses to produce a ``.miz`` when a script it is told to package is missing, and
        the real corpus is several megabytes plus a generated ``veaf-scripts.lua``. What this test
        asserts is the mission table, not the Lua, so empty files are enough.

        Args:
            root: Directory to populate (created if needed).

        Returns:
            The scripts root, ready for ``build --scripts-path``.
        """
        paths = ["src/scripts/veaf/veaf-scripts.lua"] + [s["path"] for s in get_community_script_files()]
        for relative in paths:
            stub = root / relative
            stub.parent.mkdir(parents=True, exist_ok=True)
            stub.write_text("-- test stub\n", encoding="utf-8")
        return root

    def test_scaffolded_mission_assigns_every_country_to_its_side(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            mission_folder = tmp_path / "mission"
            scripts_root = self._stub_scripts_root(tmp_path / "scripts")

            self._run("prepare", "--template", "minimal", "--theatre", _THEATRE, str(mission_folder))
            self._run("build", "mission.miz", str(mission_folder), "--scripts-path", str(scripts_root))

            built = sorted(mission_folder.glob("*.miz"))
            self.assertEqual(len(built), 1, f"expected exactly one built .miz, got {built}")
            self._run("extract", str(built[0]), str(mission_folder))

            mission = luadata.read(str(mission_folder / "src" / "mission" / "mission"), encoding="utf-8")

            # The invariant DCS enforces, asserted directly rather than through the validator: the
            # validator only reports a side with *no* country assigned, so a fix that assigned one
            # country out of three would satisfy it and still leave the mission unloadable.
            assigned = mission.get("coalitions") or {}
            checked_sides = 0
            for side, side_content in (mission.get("coalition") or {}).items():
                owners = _country_ids_holding_units(side_content)
                if not owners:
                    continue
                checked_sides += 1
                listed = {int(i) for i in indexed(assigned.get(side))}
                self.assertTrue(
                    owners <= listed,
                    f"side '{side}': countries {sorted(owners - listed)} own units but are not "
                    f"listed in coalitions.{side} ({sorted(listed)}) — DCS would refuse the mission",
                )
            # The build injects into both sides; a chain that silently stopped producing units
            # would make the loop above vacuously true.
            self.assertEqual(checked_sides, 2, "expected both blue and red to hold units after the build")

            errors = [i.message for i in validate_mission_folder(mission_folder) if i.level == ERROR]
            self.assertEqual(errors, [], f"`validate` reported errors on a freshly scaffolded mission: {errors}")


if __name__ == "__main__":
    unittest.main()
