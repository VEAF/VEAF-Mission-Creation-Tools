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

    def test_closes_stdin_bounds_timeout_and_disables_pause(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # The build must never inherit the MCP server's JSON-RPC stdin (a read there never gets
        # EOF and hangs forever — the observed deadlock): stdin is closed, the pause is disabled,
        # and a timeout bounds a stalled build.
        from veaf_tools.helpers import NO_PAUSE_ENV_VAR

        seen: dict[str, Any] = {}

        def fake_run(cmd: list[str], **kwargs: Any) -> SimpleNamespace:
            seen.update(kwargs)
            return SimpleNamespace(returncode=0, stdout="", stderr="")

        monkeypatch.setattr(build_tools.subprocess, "run", fake_run)
        build_tools.build_mission(tmp_path)

        assert seen["stdin"] is build_tools.subprocess.DEVNULL
        assert seen["timeout"] == build_tools._BUILD_TIMEOUT
        assert seen["env"][NO_PAUSE_ENV_VAR] == "1"

    def test_timeout_surfaces_as_runtime_error(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        def fake_run(cmd: list[str], **kwargs: Any) -> SimpleNamespace:
            raise build_tools.subprocess.TimeoutExpired(cmd, build_tools._BUILD_TIMEOUT)

        monkeypatch.setattr(build_tools.subprocess, "run", fake_run)
        with pytest.raises(RuntimeError, match="timed out"):
            build_tools.build_mission(tmp_path)
