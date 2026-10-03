"""Shared fixtures for veaf_mission_mcp tests."""

import zipfile
from pathlib import Path

import pytest

_SAMPLE_MISSION_LUA = b"""
mission = {
  ["coalition"] = {
    ["blue"] = {
      ["country"] = {
        [1] = {
          ["name"] = "USA",
          ["plane"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Blue Recon Flight",
                ["groupId"] = 10,
                ["units"] = {},
              },
            },
          },
        },
      },
    },
    ["red"] = {
      ["country"] = {
        [1] = {
          ["name"] = "Russia",
          ["vehicle"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Red Armor Section",
                ["groupId"] = 20,
                ["units"] = {},
              },
            },
          },
        },
      },
    },
  },
  ["triggers"] = {
    ["zones"] = {
      [1] = {
        ["name"] = "combatZone_Test",
        ["x"] = 100.0,
        ["y"] = 200.0,
        ["radius"] = 3000,
      },
    },
  },
}
"""


@pytest.fixture
def sample_miz(tmp_path: Path) -> Path:
    """A real, minimal `.miz` with one blue group, one red group and one trigger zone."""
    miz_path = tmp_path / "mission.miz"
    with zipfile.ZipFile(miz_path, "w") as zf:
        zf.writestr("mission", _SAMPLE_MISSION_LUA)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return miz_path


@pytest.fixture(autouse=True)
def _isolated_veaf_home(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """Keep the workstation's swept elevation grids out of the tests (FIX-OPEN-TRAINING-SYRIA-FINDINGS 04).

    Placement checks the surface where a grid exists, and one swept under the real VEAF home would make
    a test's warnings depend on the machine that runs it. A test that needs a grid sets its own home.
    """
    monkeypatch.setenv("VEAF_HOME", str(tmp_path / "veaf-home"))
