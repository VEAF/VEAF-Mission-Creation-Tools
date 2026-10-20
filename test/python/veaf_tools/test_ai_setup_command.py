"""`veaf-tools ai-setup` — the command that connects every AI client on the PC (FEAT-AI-ZERO-SETUP)."""

from pathlib import Path
from typing import Any

import pytest
from typer.testing import CliRunner
from veaf_libs.ai_clients import ClientResult


@pytest.fixture
def app() -> Any:
    from veaf_tools import app as app_mod
    from veaf_tools.commands import ai_setup  # noqa: F401  (registers the command)

    return app_mod.app


def _frozen(monkeypatch: pytest.MonkeyPatch, exe: Path) -> None:
    monkeypatch.setattr("sys.frozen", True, raising=False)
    monkeypatch.setattr("sys.executable", str(exe))


def test_ai_setup_declares_the_running_exe_and_reports_each_client(
    app: Any, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    exe = tmp_path / "veaf-tools.exe"
    _frozen(monkeypatch, exe)
    monkeypatch.setenv("APPDATA", str(tmp_path / "Roaming"))
    seen: dict[str, Any] = {}

    def setup_all(exe_arg: Path, *, home: Path, appdata: Path) -> list[ClientResult]:
        seen.update(exe=exe_arg, appdata=appdata)
        return [
            ClientResult("Claude Desktop", "configured", "x.json"),
            ClientResult("Claude Code", "not_found"),
            ClientResult("Gemini CLI", "not_found"),
        ]

    monkeypatch.setattr("veaf_tools.commands.ai_setup.setup_all", setup_all)

    result = CliRunner().invoke(app, ["ai-setup"])

    assert result.exit_code == 0, result.output
    assert seen == {"exe": exe.resolve(), "appdata": tmp_path / "Roaming"}
    assert "Claude Desktop" in result.output and "Gemini CLI" in result.output


def test_ai_setup_fails_when_a_client_could_not_be_configured(
    app: Any, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _frozen(monkeypatch, tmp_path / "veaf-tools.exe")
    monkeypatch.setattr(
        "veaf_tools.commands.ai_setup.setup_all",
        lambda *_a, **_k: [ClientResult("Claude Desktop", "failed", "not valid JSON")],
    )

    result = CliRunner().invoke(app, ["ai-setup"])

    assert result.exit_code == 1
    assert "not valid JSON" in result.output


def test_ai_setup_with_no_client_found_says_so(app: Any, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _frozen(monkeypatch, tmp_path / "veaf-tools.exe")
    monkeypatch.setattr(
        "veaf_tools.commands.ai_setup.setup_all",
        lambda *_a, **_k: [ClientResult("Claude Desktop", "not_found"), ClientResult("Gemini CLI", "not_found")],
    )

    result = CliRunner().invoke(app, ["ai-setup"])

    assert result.exit_code == 1
    assert "AI_ASSISTANT_INSTALL" in result.output


def test_ai_setup_refuses_to_declare_a_python_interpreter(app: Any, monkeypatch: pytest.MonkeyPatch) -> None:
    """From `poetry run`, `sys.executable` is python.exe: declaring it would start nothing useful."""
    monkeypatch.delattr("sys.frozen", raising=False)
    called: list[bool] = []
    monkeypatch.setattr("veaf_tools.commands.ai_setup.setup_all", lambda *_a, **_k: called.append(True) or [])

    result = CliRunner().invoke(app, ["ai-setup"])

    assert result.exit_code != 0
    assert called == []


@pytest.mark.parametrize(
    ("args", "expected"),
    [
        (["mcp"], True),
        (["--lang", "fr", "mcp"], True),
        (["--lang=fr", "mcp"], True),
        (["about"], False),
        (["mission", "build"], False),
        ([], False),
    ],
)
def test_is_mcp_invocation(args: list[str], expected: bool) -> None:
    """`veaf-tools mcp` prints no banner: its stdout is the JSON-RPC stream (FEAT-AI-ZERO-SETUP)."""
    from veaf_tools.app import is_mcp_invocation

    assert is_mcp_invocation(args) is expected
