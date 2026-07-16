"""Tests for the `scaffold_mission` action (wave 9).

The action downloads and runs real binaries; these tests mock the HTTP download and
`subprocess.run` to assert the **orchestration** — the download → run-updater → run-prepare
sequence, the argument shape, the working directory, and the guard/failure paths — not a real
network install (that is a manual end-to-end check).
"""

from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest
from veaf_libs import platform_assets
from veaf_mission_mcp import scaffold


class _FakeResponse:
    def __init__(self, content: bytes = b"MZ-fake-binary") -> None:
        self.content = content

    def raise_for_status(self) -> None:  # pragma: no cover - trivial
        return None


@pytest.fixture
def recorder(monkeypatch: pytest.MonkeyPatch) -> dict[str, list[Any]]:
    """Mock the download + subprocess seams and record every call.

    The fake updater run creates the artifacts a real updater would (`veaf-tools[.exe]` and
    `published/package.json`) so the post-updater checks pass on the happy path.
    """
    calls: dict[str, list[Any]] = {"downloads": [], "runs": []}

    def fake_get(url: str, **kwargs: Any) -> _FakeResponse:
        calls["downloads"].append({"url": url, "kwargs": kwargs})
        return _FakeResponse()

    def fake_run(cmd: list[str], **kwargs: Any) -> SimpleNamespace:
        calls["runs"].append({"cmd": cmd, "kwargs": kwargs})
        cwd = Path(kwargs["cwd"])
        if "updater" in Path(cmd[0]).name:
            (cwd / platform_assets.veaf_tools_binary_name()).write_text("x", encoding="utf-8")
            published = cwd / "published"
            published.mkdir(exist_ok=True)
            (published / "package.json").write_text('{"version": "6.9.9"}', encoding="utf-8")
        return SimpleNamespace(returncode=0, stdout="", stderr="")

    monkeypatch.setattr(scaffold.requests, "get", fake_get)
    monkeypatch.setattr(scaffold.subprocess, "run", fake_run)
    return calls


class TestScaffoldMission:
    def test_happy_path_download_then_updater_then_prepare(
        self, tmp_path: Path, recorder: dict[str, list[Any]]
    ) -> None:
        target = tmp_path / "new-mission"
        result = scaffold.scaffold_mission(str(target), template="standard")

        # One download: the updater asset for this OS.
        assert len(recorder["downloads"]) == 1
        assert platform_assets.release_updater_asset_name() in recorder["downloads"][0]["url"]

        # Two runs, in order: the updater, then veaf-tools prepare.
        assert len(recorder["runs"]) == 2
        updater_run, prepare_run = recorder["runs"]
        assert Path(updater_run["cmd"][0]).name == platform_assets.updater_binary_name()
        assert Path(updater_run["kwargs"]["cwd"]) == target
        assert Path(prepare_run["cmd"][0]).name == platform_assets.veaf_tools_binary_name()
        assert prepare_run["cmd"][1:] == ["prepare", "--template", "standard", "--force"]
        assert Path(prepare_run["kwargs"]["cwd"]) == target

        assert result["folder"] == str(target)
        assert result["template"] == "standard"
        assert result["veaf_tools_version"] == "6.9.9"

    def test_token_and_tag_relayed_to_updater(self, tmp_path: Path, recorder: dict[str, list[Any]]) -> None:
        scaffold.scaffold_mission(str(tmp_path / "m"), template="minimal", github_token="ghp_x", tag="published-v6.9.9")
        updater_cmd = recorder["runs"][0]["cmd"]
        assert "--token" in updater_cmd and "ghp_x" in updater_cmd
        assert "--tag" in updater_cmd and "published-v6.9.9" in updater_cmd
        # The tag is also used to build the download URL.
        assert "published-v6.9.9" in recorder["downloads"][0]["url"]

    def test_rejects_non_empty_folder_before_any_work(self, tmp_path: Path, recorder: dict[str, list[Any]]) -> None:
        target = tmp_path / "busy"
        target.mkdir()
        (target / "leftover.txt").write_text("x", encoding="utf-8")

        with pytest.raises(ValueError, match="not empty"):
            scaffold.scaffold_mission(str(target), template="standard")

        assert recorder["downloads"] == [] and recorder["runs"] == []

    def test_rejects_invalid_template_before_any_work(self, tmp_path: Path, recorder: dict[str, list[Any]]) -> None:
        with pytest.raises(ValueError, match="template"):
            scaffold.scaffold_mission(str(tmp_path / "m"), template="custom")

        assert recorder["downloads"] == [] and recorder["runs"] == []

    def test_updater_nonzero_exit_surfaces(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(scaffold.requests, "get", lambda url, **k: _FakeResponse())
        monkeypatch.setattr(
            scaffold.subprocess, "run", lambda cmd, **k: SimpleNamespace(returncode=1, stdout="", stderr="boom")
        )
        with pytest.raises(RuntimeError, match="updater"):
            scaffold.scaffold_mission(str(tmp_path / "m"), template="standard")

    def test_missing_veaf_tools_after_updater_surfaces(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        # Updater "succeeds" but installs nothing.
        monkeypatch.setattr(scaffold.requests, "get", lambda url, **k: _FakeResponse())
        monkeypatch.setattr(
            scaffold.subprocess, "run", lambda cmd, **k: SimpleNamespace(returncode=0, stdout="", stderr="")
        )
        with pytest.raises(RuntimeError, match="veaf-tools|published"):
            scaffold.scaffold_mission(str(tmp_path / "m"), template="standard")

    def test_prepare_nonzero_exit_surfaces(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(scaffold.requests, "get", lambda url, **k: _FakeResponse())

        def fake_run(cmd: list[str], **kwargs: Any) -> SimpleNamespace:
            cwd = Path(kwargs["cwd"])
            if "updater" in Path(cmd[0]).name:
                (cwd / platform_assets.veaf_tools_binary_name()).write_text("x", encoding="utf-8")
                (cwd / "published").mkdir(exist_ok=True)
                return SimpleNamespace(returncode=0, stdout="", stderr="")
            return SimpleNamespace(returncode=2, stdout="", stderr="prepare failed")

        monkeypatch.setattr(scaffold.subprocess, "run", fake_run)
        with pytest.raises(RuntimeError, match="prepare"):
            scaffold.scaffold_mission(str(tmp_path / "m"), template="standard")
