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
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "Local"))
    seen: dict[str, Any] = {}

    def setup_all(
        exe_arg: Path,
        *,
        home: Path,
        appdata: Path,
        localappdata: Path,
        cherry_assistants: list[str],
        cherry_data_dir: Path | None,
        only: list[str],
    ) -> list[ClientResult]:
        seen.update(
            exe=exe_arg, appdata=appdata, localappdata=localappdata, cherry_assistants=cherry_assistants, only=only
        )
        return [
            ClientResult("Claude Desktop", "configured", "x.json"),
            ClientResult("Claude Code", "not_found"),
            ClientResult("Gemini CLI", "not_found"),
        ]

    monkeypatch.setattr("veaf_tools.commands.ai_setup.setup_all", setup_all)

    result = CliRunner().invoke(app, ["ai-setup"])

    assert result.exit_code == 0, result.output
    assert seen == {
        "exe": exe.resolve(),
        "appdata": tmp_path / "Roaming",
        "localappdata": tmp_path / "Local",
        "cherry_assistants": [],
        "only": [],
    }
    assert "Claude Desktop" in result.output and "Gemini CLI" in result.output


def test_ai_setup_passes_the_cherry_assistants_on(app: Any, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """`--cherry-assistant`, repeatable, names the Cherry Studio assistants to link (FEAT-CHERRY-AI-SETUP)."""
    _frozen(monkeypatch, tmp_path / "veaf-tools.exe")
    seen: list[Any] = []

    def setup_all(
        *_a: Any, cherry_assistants: list[str], cherry_data_dir: Path | None, **_k: Any
    ) -> list[ClientResult]:
        seen.append((cherry_assistants, cherry_data_dir))
        return [ClientResult("Cherry Studio", "configured", "cherrystudio.sqlite")]

    monkeypatch.setattr("veaf_tools.commands.ai_setup.setup_all", setup_all)

    result = CliRunner().invoke(
        app, ["ai-setup", "--cherry-assistant", "VEAF missions", "--cherry-assistant", "VEAF chatbot"]
    )
    forced = CliRunner().invoke(app, ["ai-setup", "--cherry-data-dir", str(tmp_path / "E profile")])

    assert result.exit_code == 0, result.output
    assert forced.exit_code == 0, forced.output
    assert seen == [(["VEAF missions", "VEAF chatbot"], None), ([], tmp_path / "E profile")]


def _stub_every_client(monkeypatch: pytest.MonkeyPatch) -> list[str]:
    """Stub each client's setup, so the real `setup_all` runs without touching this PC."""
    from veaf_libs import ai_clients

    called: list[str] = []
    for name in ("claude_desktop", "claude_code", "gemini", "antigravity", "codex", "opencode", "cherry"):

        def stub(*_a: Any, _n: str = name, **_k: Any) -> ClientResult:
            called.append(_n)
            return ClientResult(_n, "configured", "stub")

        monkeypatch.setattr(ai_clients, f"setup_{name}", stub)
    return called


def test_ai_setup_only_cherry_touches_cherry_alone(app: Any, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """`--only cherry` sets up Cherry Studio and leaves every other client unread (FEAT-CHERRY-AI-SETUP)."""
    _frozen(monkeypatch, tmp_path / "veaf-tools.exe")
    called = _stub_every_client(monkeypatch)

    result = CliRunner().invoke(app, ["ai-setup", "--only", "cherry"])

    assert result.exit_code == 0, result.output
    assert called == ["cherry"]


def test_ai_setup_refuses_an_unknown_client(app: Any, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _frozen(monkeypatch, tmp_path / "veaf-tools.exe")
    called = _stub_every_client(monkeypatch)

    result = CliRunner().invoke(app, ["ai-setup", "--only", "cherri"])

    assert result.exit_code != 0
    assert "cherri" in result.output and "cherry" in result.output
    assert called == []


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
