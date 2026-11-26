"""Tests for validate_mission + build_mission (FEAT-MCP-MISSION-EDITOR-035)."""

import os
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
        assert result["log"] == "built ok"
        assert Path(result["log_file"]).read_text(encoding="utf-8") == "built ok\n"

    def test_returns_the_log_without_progress_lines_or_the_folder_path(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """MCP-CONTEXT-BUDGET: 14 004 characters, two thirds of them the folder's path and progress lines."""
        folder = str(tmp_path)
        raw = (
            "Pipeline : construction\n"
            f"✓ lecture de la mission {folder}{os.sep}Night.miz terminé !La coalition 'blue' n'avait aucune unité\n"
            f"✓ Done reading {folder}{os.sep}src{os.sep}versions.yaml!\n"
            f"Créé : {folder}{os.sep}missions{os.sep}Night_noon.miz\n"
            "\n"
            f"Dossier {folder}\n"
        )
        seen: dict[str, Any] = {}

        def fake_run(cmd: list[str], **kwargs: Any) -> SimpleNamespace:
            seen["env"] = kwargs["env"]
            return SimpleNamespace(returncode=0, stdout=raw, stderr="")

        monkeypatch.setattr(build_tools.subprocess, "run", fake_run)
        result = build_tools.build_mission(tmp_path)

        assert seen["env"]["COLUMNS"] == "4000"  # unwrapped, so the path is whole and found
        assert result["log"] == (
            "Pipeline : construction\n"
            "La coalition 'blue' n'avait aucune unité\n"
            f"Créé : missions{os.sep}Night_noon.miz\n"
            "Dossier ."
        )
        assert Path(result["log_file"]).read_text(encoding="utf-8") == raw.strip() + "\n"

    def test_lists_the_miz_the_build_wrote(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """FEAT-ROLE-TRAINING-VARIANTS: a training: block makes one build write five .miz."""
        import os

        old = tmp_path / "Night_20261001.miz"
        old.write_bytes(b"old")
        os.utime(old, (0, 0))

        def fake_run(cmd: list[str], **kwargs: Any) -> SimpleNamespace:
            for suffix in ("", "_TRAINING_A2G"):
                (tmp_path / f"Night_20261103{suffix}.miz").write_bytes(b"new")
            return SimpleNamespace(returncode=0, stdout="built ok", stderr="")

        monkeypatch.setattr(build_tools.subprocess, "run", fake_run)
        missions = build_tools.build_mission(tmp_path)["missions"]

        assert [Path(m).name for m in missions] == ["Night_20261103.miz", "Night_20261103_TRAINING_A2G.miz"]

    def test_passes_a_build_profile(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """Ticket 19: LOCAL_TEST could not be built through the MCP."""
        seen: dict[str, Any] = {}
        monkeypatch.setattr(
            build_tools.subprocess,
            "run",
            lambda cmd, **k: seen.update(cmd=cmd) or SimpleNamespace(returncode=0, stdout="", stderr=""),
        )
        build_tools.build_mission(tmp_path, profile="LOCAL_TEST")
        assert seen["cmd"][1:] == ["build", "--profile", "LOCAL_TEST"]

    def test_no_profile_builds_as_before(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        seen: dict[str, Any] = {}
        monkeypatch.setattr(
            build_tools.subprocess,
            "run",
            lambda cmd, **k: seen.update(cmd=cmd) or SimpleNamespace(returncode=0, stdout="", stderr=""),
        )
        build_tools.build_mission(tmp_path)
        assert seen["cmd"][1:] == ["build"]

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


def test_the_compact_profile_drops_the_step_lines(monkeypatch: pytest.MonkeyPatch) -> None:
    """Run 8: each of three builds carried 14 lines of file read, file written, YAML valid."""
    monkeypatch.setenv("VEAF_MCP_PROFILE", "compact")
    log = "\n".join(
        [
            "Lecture du fichier mission Night.miz",
            "Validation YAML réussie",
            "Mission written successfully",
            "16 radio(s) tiennent moins de presets que leur liste",
            "  Préréglages injectés dans 43 aéronefs",
        ]
    )
    assert build_tools.drop_step_lines(log).splitlines() == [
        "16 radio(s) tiennent moins de presets que leur liste",
        "  Préréglages injectés dans 43 aéronefs",
    ]
