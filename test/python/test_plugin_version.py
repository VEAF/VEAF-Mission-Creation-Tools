"""The agent manifests' version must track the veaf-tools version.

The plugin (`plugin/.claude-plugin/plugin.json`), the Gemini CLI extension
(`plugin/gemini-extension.json`) and the tools (`pyproject.toml`) ship as one product; a maker seeing
the plugin at `0.2.0` while the tools are at `6.9.x` is confusing. This guard fails the CI whenever any
of them drifts, so a version bump must touch all of them.

The two manifests live in the **same directory on purpose** — see `plugin/README.md`: Claude Code and
Gemini CLI both look for skills in `<root>/skills/<name>/SKILL.md`, so one folder serves both and the
authoring guidance exists once.
"""

from __future__ import annotations

import json
import tomllib
from pathlib import Path

import pytest

#: Manifest path (relative to the repo root) → the JSON key holding its version.
AGENT_MANIFESTS = {
    Path("plugin") / ".claude-plugin" / "plugin.json": "version",
    Path("plugin") / "gemini-extension.json": "version",
}


def _repo_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        if (parent / "pyproject.toml").is_file():
            return parent
    raise RuntimeError("repo root (with pyproject.toml) not found")


def _tools_version(root: Path) -> str:
    parsed = tomllib.loads((root / "pyproject.toml").read_text(encoding="utf-8"))
    version: str = parsed["tool"]["poetry"]["version"]
    return version


@pytest.mark.parametrize("manifest, key", sorted(AGENT_MANIFESTS.items()))
def test_agent_manifest_version_matches_veaf_tools_version(manifest: Path, key: str) -> None:
    root = _repo_root()
    tools_version = _tools_version(root)
    manifest_version = json.loads((root / manifest).read_text(encoding="utf-8"))[key]
    assert manifest_version == tools_version, (
        f"{manifest.as_posix()} version ({manifest_version}) must match pyproject veaf-tools version "
        f"({tools_version}) — bump them together."
    )


def test_both_manifests_declare_the_same_mcp_server_name() -> None:
    """A skill that names an MCP server is useless if the two agents register it differently.

    `SKILL.md` is shared verbatim between Claude Code and Gemini CLI, and its guidance refers to the
    server's actions. If one manifest called the server `veaf-mission-editor` and the other
    `veaf-tools`, the same skill text would be wrong on one of the two — silently, since neither agent
    validates a skill against the servers it has.
    """
    root = _repo_root()
    claude_servers = json.loads((root / "plugin" / ".mcp.json").read_text(encoding="utf-8"))["mcpServers"]
    gemini_servers = json.loads((root / "plugin" / "gemini-extension.json").read_text(encoding="utf-8"))["mcpServers"]
    assert set(claude_servers) == set(gemini_servers), (
        f"MCP server names differ: Claude declares {sorted(claude_servers)}, "
        f"Gemini declares {sorted(gemini_servers)} — the shared SKILL.md names them."
    )


def test_the_shared_skill_is_where_both_agents_look() -> None:
    """Both agents discover skills at `<root>/skills/<name>/SKILL.md`, which is why there is one copy.

    Guards the arrangement rather than the content: moving the skill under `.claude-plugin/`, or into a
    second copy for Gemini, would break Gemini's discovery or start the drift the lot set out to avoid.
    """
    root = _repo_root()
    skills_dir = root / "plugin" / "skills"
    skills = sorted(path.parent.name for path in skills_dir.glob("*/SKILL.md"))
    assert skills == ["veaf-mission-authoring"], (
        f"expected exactly the shared authoring skill under {skills_dir.as_posix()}, found {skills}"
    )
