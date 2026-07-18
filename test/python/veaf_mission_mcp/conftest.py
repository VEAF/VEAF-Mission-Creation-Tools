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
