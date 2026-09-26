"""FIX-SCRATCH-MISSION-FINDINGS ticket 08 — what the MCP actions leave behind, besides the edit.

Measured in one GermanyCW-v6 session: 45 to 51 timestamped copies of `src/mission/mission` next to
the file — in the directory the build packs and the mission maker commits — a `set_airbase_coalition`
that rewrote `mission` (LF → CRLF, nothing else) and backed it up to change `warehouses` only, and
forced `dynamicSpawn` on 40 red bases the maker wanted no slot on; a `remove_group` warning about a
"combat zone" that was a QRA zone; and a `build_mission` output cut to its last lines and decoded
as cp1252 (« CrÃ©Ã© »), so the warnings the maker needed were gone.
"""

import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any
from unittest import mock

from mission_tools.miz_backup import MAX_BACKUPS_PER_FILE, backup_before_write
from mission_tools.miz_tools import read_mission_folder, write_mission_folder
from veaf_mission_mcp import build_tools
from veaf_mission_mcp.airbase import set_airbase_coalition
from veaf_mission_mcp.remove_group import remove_group

_MISSION = """\
mission =
{
  ["theatre"] = "Caucasus",
  ["coalition"] =
  {
    ["red"] =
    {
      ["country"] =
      {
        [1] =
        {
          ["id"] = 0,
          ["name"] = "Russia",
          ["plane"] =
          {
            ["group"] =
            {
              [1] =
              {
                ["name"] = "QRA_Stendal-MiG21",
                ["groupId"] = 1,
                ["units"] =
                {
                  [1] =
                  {
                    ["name"] = "QRA_Stendal-MiG21-1",
                    ["type"] = "MiG-21Bis",
                  },
                },
              },
            },
          },
        },
      },
    },
  },
  ["triggers"] =
  {
    ["zones"] =
    {
      [1] =
      {
        ["name"] = "QRA_Stendal",
        ["x"] = 0,
        ["y"] = 0,
        ["radius"] = 1000,
      },
    },
  },
}
"""

_WAREHOUSES = 'warehouses = \n{\n  ["airports"] = \n  {\n  },\n}\n'


def _folder(tmp_path: Path, yaml_text: str = "modules:\n  QRA: true\n") -> Path:
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_bytes(_MISSION.encode("utf-8"))
    (exploded / "warehouses").write_bytes(_WAREHOUSES.encode("utf-8"))
    (exploded / "theatre").write_text("Caucasus", encoding="utf-8")
    (tmp_path / "mission.yaml").write_text(yaml_text, encoding="utf-8")
    return tmp_path


class TestBackupsLeaveTheSource:
    def test_a_folder_file_is_backed_up_outside_src(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        backup = backup_before_write(folder / "src" / "mission" / "mission")
        assert backup.parent == folder / ".veaf-backups"
        assert not list((folder / "src" / "mission").glob("mission.*"))

    def test_mission_yaml_is_backed_up_outside_the_folder_root(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        backup = backup_before_write(folder / "mission.yaml")
        assert backup.parent == folder / ".veaf-backups"
        assert backup.suffix == ".yaml"

    def test_the_backup_directory_ignores_itself(self, tmp_path: Path) -> None:
        """A mission maker commits the folder: the backups must not follow, whatever that folder's .gitignore says."""
        folder = _folder(tmp_path)
        backup_before_write(folder / "mission.yaml")
        assert (folder / ".veaf-backups" / ".gitignore").read_text(encoding="utf-8").strip() == "*"

    def test_the_backups_are_capped(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        start = datetime(2026, 9, 23, 10, 0, 0)
        for i in range(MAX_BACKUPS_PER_FILE + 5):
            backup_before_write(folder / "src" / "mission" / "mission", now=start + timedelta(seconds=i))
        kept = sorted(p.name for p in (folder / ".veaf-backups").glob("mission.2026*"))
        assert len(kept) == MAX_BACKUPS_PER_FILE
        assert kept[0] == "mission.20260923-100005", "the oldest go first"

    def test_the_cap_counts_each_file_on_its_own(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        start = datetime(2026, 9, 23, 10, 0, 0)
        for i in range(MAX_BACKUPS_PER_FILE + 1):
            backup_before_write(folder / "src" / "mission" / "mission", now=start + timedelta(seconds=i))
        backup_before_write(folder / "mission.yaml", now=start)
        assert len(list((folder / ".veaf-backups").glob("mission.*.yaml"))) == 1

    def test_a_miz_outside_any_folder_keeps_its_sibling_backup(self, tmp_path: Path) -> None:
        miz = tmp_path / "lone.miz"
        miz.write_bytes(b"x")
        assert backup_before_write(miz).parent == tmp_path


class TestSetAirbaseCoalition:
    def test_the_mission_file_is_not_rewritten(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        # A folder the tools have written once holds its tables normalised (sorted keys); the first
        # write of a hand-made fixture reorders it, which is not the change this test is about.
        write_mission_folder(read_mission_folder(folder), folder)
        before = (folder / "src" / "mission" / "mission").read_bytes()
        set_airbase_coalition(folder, name="Kutaisi", coalition="blue")
        assert (folder / "src" / "mission" / "mission").read_bytes() == before
        backups = [p.name for p in (folder / ".veaf-backups").iterdir() if p.name != ".gitignore"]
        assert backups and all(name.startswith("warehouses.") for name in backups)

    def test_dynamic_spawn_is_a_choice(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        result = set_airbase_coalition(folder, name="Kutaisi", coalition="red", dynamic_spawn=False)
        assert result["dynamic_spawn"] is False
        airports = read_mission_folder(folder).warehouses_content["airports"]
        entry = next(iter(airports.values())) if isinstance(airports, dict) else airports[0]
        assert entry["dynamicSpawn"] is False

    def test_the_files_stay_lf(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_airbase_coalition(folder, name="Kutaisi", coalition="blue")
        assert b"\r\n" not in (folder / "src" / "mission" / "warehouses").read_bytes()


class TestRemoveGroupWarnsOnlyForRealCombatZones:
    def test_a_qra_zone_is_not_a_combat_zone(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        result = remove_group(folder, group_name="QRA_Stendal-MiG21")
        assert not any("Combat zone" in w for w in result["warnings"])

    def test_a_declared_combat_zone_still_warns(self, tmp_path: Path) -> None:
        folder = _folder(
            tmp_path, "modules:\n  COMBATZONE:\n    combat_zones:\n      - type: zone\n        zone_name: QRA_Stendal\n"
        )
        result = remove_group(folder, group_name="QRA_Stendal-MiG21")
        assert any("Combat zone 'QRA_Stendal'" in w for w in result["warnings"])


class TestBuildMissionOutput:
    def _run(self, tmp_path: Path, stdout: str) -> tuple[dict[str, Any], Any]:
        completed = subprocess.CompletedProcess(args=[], returncode=0, stdout=stdout, stderr="")
        with mock.patch.object(build_tools.subprocess, "run", return_value=completed) as run:
            result = build_tools.build_mission(tmp_path)
        return result, run

    def test_the_whole_log_is_returned(self, tmp_path: Path) -> None:
        log = "\n".join(f"line {i}" for i in range(400)) + "\nÉchec de la récupération du METAR pour ETAR"
        result, _ = self._run(tmp_path, log)
        assert result["log"] == log
        assert "line 0" in result["log"]

    def test_the_output_is_decoded_as_utf8(self, tmp_path: Path) -> None:
        _, run = self._run(tmp_path, "Créé")
        kwargs = run.call_args.kwargs
        assert kwargs["encoding"] == "utf-8"
