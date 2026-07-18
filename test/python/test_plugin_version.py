"""The Claude plugin manifest version must track the veaf-tools version.

The plugin (`plugin/.claude-plugin/plugin.json`) and the tools (`pyproject.toml`) ship as one
product; a maker seeing the plugin at `0.2.0` while the tools are at `6.9.x` is confusing. This
guard fails the CI whenever the two drift, so any version bump must touch both.
"""

from __future__ import annotations

import json
import tomllib
from pathlib import Path


def _repo_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        if (parent / "pyproject.toml").is_file():
            return parent
    raise RuntimeError("repo root (with pyproject.toml) not found")


def test_plugin_manifest_version_matches_veaf_tools_version() -> None:
    root = _repo_root()
    tools_version = tomllib.loads((root / "pyproject.toml").read_text(encoding="utf-8"))["tool"]["poetry"]["version"]
    plugin_version = json.loads((root / "plugin" / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))[
        "version"
    ]
    assert plugin_version == tools_version, (
        f"plugin.json version ({plugin_version}) must match pyproject veaf-tools version "
        f"({tools_version}) — bump both together."
    )
