"""Tests for validate_mission + build_mission (FEAT-MCP-MISSION-EDITOR-035)."""

from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest
from veaf_libs import platform_assets
from veaf_mission_mcp import build_tools


class TestValidateMission:
    def test_missing_mission_yaml_is_an_error(self, tmp_path: Path) -> None:
        result = build_tools.validate_mission(tmp_path)

        assert result["ok"] is False
        assert result["errors"]  # at least the "no mission.yaml" error
        assert isinstance(result["warnings"], list)
        assert result["folder"] == str(tmp_path)


class TestBuildMission:
    def test_runs_veaf_tools_build_in_the_folder(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        calls: dict[str, Any] = {}

        def fake_run(cmd: list[str], **kwargs: Any) -> SimpleNamespace:
            calls["cmd"] = cmd
            calls["cwd"] = kwargs.get("cwd")
            return SimpleNamespace(returncode=0, stdout="built ok", stderr="")

        monkeypatch.setattr(build_tools.subprocess, "run", fake_run)
        result = build_tools.build_mission(tmp_path)

        assert calls["cmd"][1] == "build"
        assert Path(calls["cwd"]) == tmp_path
        assert result["ok"] is True
        assert "built ok" in result["message"]

    def test_uses_the_folders_installed_binary_when_present(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        (tmp_path / platform_assets.veaf_tools_binary_name()).write_text("x", encoding="utf-8")
        seen: dict[str, Any] = {}
        monkeypatch.setattr(
            build_tools.subprocess,
            "run",
            lambda cmd, **k: seen.update(cmd=cmd) or SimpleNamespace(returncode=0, stdout="", stderr=""),
        )
        build_tools.build_mission(tmp_path)
        assert Path(seen["cmd"][0]).name == platform_assets.veaf_tools_binary_name()
        assert Path(seen["cmd"][0]).parent == tmp_path

    def test_nonzero_exit_surfaces(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(
            build_tools.subprocess,
            "run",
            lambda cmd, **k: SimpleNamespace(returncode=2, stdout="", stderr="boom"),
        )
        with pytest.raises(RuntimeError, match="build failed"):
            build_tools.build_mission(tmp_path)
