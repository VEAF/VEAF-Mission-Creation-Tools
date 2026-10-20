"""Tests for veaf_libs.ai_clients — declaring the MCP server in the AI clients (FEAT-AI-ZERO-SETUP)."""

import json
import os
import subprocess
from pathlib import Path
from typing import Any

import pytest
from veaf_libs.ai_clients import (
    SERVER_KEY,
    find_claude_cli,
    merge_server_into_json,
    setup_antigravity,
    setup_claude_code,
    setup_claude_desktop,
    setup_codex,
    setup_gemini,
    setup_opencode,
)

EXE = Path(r"C:\VEAF\outils\veaf-tools.exe")
ENTRY = {"command": str(EXE), "args": ["mcp"]}


def _read(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def test_merge_creates_the_file_with_the_server(tmp_path: Path) -> None:
    config = tmp_path / "settings.json"

    merge_server_into_json(config, EXE)

    assert _read(config) == {"mcpServers": {SERVER_KEY: ENTRY}}


def test_merge_keeps_every_other_setting_and_server(tmp_path: Path) -> None:
    config = tmp_path / "settings.json"
    config.write_text(json.dumps({"theme": "GitHub", "mcpServers": {"other": {"command": "x"}}}), encoding="utf-8")

    merge_server_into_json(config, EXE)

    assert _read(config) == {"theme": "GitHub", "mcpServers": {"other": {"command": "x"}, SERVER_KEY: ENTRY}}


def test_merge_twice_is_the_same_as_once(tmp_path: Path) -> None:
    config = tmp_path / "settings.json"
    merge_server_into_json(config, Path(r"C:\old\veaf-tools.exe"))

    merge_server_into_json(config, EXE)
    merge_server_into_json(config, EXE)

    assert _read(config) == {"mcpServers": {SERVER_KEY: ENTRY}}


def test_merge_refuses_a_file_it_cannot_read_and_leaves_it_alone(tmp_path: Path) -> None:
    config = tmp_path / "settings.json"
    config.write_text("{ not json", encoding="utf-8")

    with pytest.raises(ValueError):
        merge_server_into_json(config, EXE)

    assert config.read_text(encoding="utf-8") == "{ not json"


def test_merge_treats_an_empty_file_as_no_setting(tmp_path: Path) -> None:
    config = tmp_path / "settings.json"
    config.write_text("", encoding="utf-8")

    merge_server_into_json(config, EXE)

    assert _read(config) == {"mcpServers": {SERVER_KEY: ENTRY}}


def test_claude_desktop_is_configured_in_its_appdata_folder(tmp_path: Path) -> None:
    (tmp_path / "Claude").mkdir()

    result = setup_claude_desktop(EXE, appdata=tmp_path)

    assert result.status == "configured"
    assert _read(tmp_path / "Claude" / "claude_desktop_config.json")["mcpServers"][SERVER_KEY] == ENTRY


def test_claude_desktop_absent_is_not_found(tmp_path: Path) -> None:
    result = setup_claude_desktop(EXE, appdata=tmp_path)

    assert result.status == "not_found"
    assert not (tmp_path / "Claude").exists()


def test_claude_desktop_with_an_unreadable_config_fails_without_touching_it(tmp_path: Path) -> None:
    (tmp_path / "Claude").mkdir()
    (tmp_path / "Claude" / "claude_desktop_config.json").write_text("{", encoding="utf-8")

    result = setup_claude_desktop(EXE, appdata=tmp_path)

    assert result.status == "failed"
    assert (tmp_path / "Claude" / "claude_desktop_config.json").read_text(encoding="utf-8") == "{"


def test_gemini_is_configured_in_its_settings(tmp_path: Path) -> None:
    (tmp_path / ".gemini").mkdir()
    (tmp_path / ".gemini" / "settings.json").write_text(json.dumps({"theme": "GitHub"}), encoding="utf-8")

    result = setup_gemini(EXE, home=tmp_path)

    assert result.status == "configured"
    assert _read(tmp_path / ".gemini" / "settings.json") == {"theme": "GitHub", "mcpServers": {SERVER_KEY: ENTRY}}


def test_gemini_absent_is_not_found(tmp_path: Path) -> None:
    assert setup_gemini(EXE, home=tmp_path).status == "not_found"


def test_claude_code_goes_through_its_cli_when_there_is_one(tmp_path: Path) -> None:
    """Claude Code rewrites ~/.claude.json while it runs: its own CLI is the safe way in."""
    calls: list[list[str]] = []

    def run(cmd: list[str], **_kwargs: Any) -> subprocess.CompletedProcess[str]:
        calls.append(cmd)
        return subprocess.CompletedProcess(cmd, 0, "", "")

    result = setup_claude_code(EXE, home=tmp_path, which=lambda: "claude", run=run)

    assert result.status == "configured"
    assert calls == [
        ["claude", "mcp", "remove", "--scope", "user", SERVER_KEY],
        ["claude", "mcp", "add-json", "--scope", "user", SERVER_KEY, json.dumps(ENTRY)],
    ]
    assert not (tmp_path / ".claude.json").exists()


def test_claude_code_cli_failure_is_reported(tmp_path: Path) -> None:
    def run(cmd: list[str], **_kwargs: Any) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(cmd, 1 if "add-json" in cmd else 0, "", "boom")

    result = setup_claude_code(EXE, home=tmp_path, which=lambda: "claude", run=run)

    assert result.status == "failed"
    assert "boom" in result.detail


def test_claude_code_without_its_cli_is_configured_in_its_file(tmp_path: Path) -> None:
    (tmp_path / ".claude.json").write_text(json.dumps({"numStartups": 3}), encoding="utf-8")

    result = setup_claude_code(EXE, home=tmp_path, which=lambda: None)

    assert result.status == "configured"
    assert _read(tmp_path / ".claude.json") == {"numStartups": 3, "mcpServers": {SERVER_KEY: ENTRY}}


def test_claude_code_absent_is_not_found(tmp_path: Path) -> None:
    assert setup_claude_code(EXE, home=tmp_path, which=lambda: None).status == "not_found"


def test_find_claude_cli_searches_the_path_folders_only(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """A `claude` executable in the current folder is not Claude Code: never run it."""
    name = "claude.exe" if os.name == "nt" else "claude"
    planted, on_path = tmp_path / "tools", tmp_path / "bin"
    planted.mkdir()
    on_path.mkdir()
    (planted / name).write_bytes(b"")
    monkeypatch.chdir(planted)

    (planted / "sub").mkdir()
    (planted / "sub" / name).write_bytes(b"")
    assert find_claude_cli(path_env=os.pathsep.join(["", ".", "sub", str(tmp_path / "missing")])) is None

    (on_path / name).write_bytes(b"")
    assert find_claude_cli(path_env=os.pathsep.join([".", f'"{on_path}"'])) == str(on_path / name)


def test_find_claude_cli_ignores_a_batch_shim(tmp_path: Path) -> None:
    """`cmd.exe` would re-read the JSON argument: a `claude.cmd` falls back to editing the file."""
    (tmp_path / "claude.cmd").write_text("@echo off", encoding="utf-8")

    assert find_claude_cli(path_env=str(tmp_path)) is None


def test_merge_reads_a_file_notepad_saved_with_a_bom(tmp_path: Path) -> None:
    """The manual install had users edit this file in Notepad, which may write a BOM."""
    config = tmp_path / "claude_desktop_config.json"
    config.write_bytes(b"\xef\xbb\xbf" + json.dumps({"preferences": {}}).encode("utf-8"))

    merge_server_into_json(config, EXE)

    assert _read(config) == {"preferences": {}, "mcpServers": {SERVER_KEY: ENTRY}}


def test_claude_code_cli_failure_falls_back_to_its_file(tmp_path: Path) -> None:
    """`remove` ran, `add-json` failed: the file still gets the server, rather than nothing."""
    (tmp_path / ".claude.json").write_text(json.dumps({"numStartups": 3}), encoding="utf-8")

    def run(cmd: list[str], **_kwargs: Any) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(cmd, 1 if "add-json" in cmd else 0, "", "unknown command")

    result = setup_claude_code(EXE, home=tmp_path, which=lambda: "claude", run=run)

    assert result.status == "configured"
    assert _read(tmp_path / ".claude.json")["mcpServers"][SERVER_KEY] == ENTRY


def test_claude_code_cli_that_cannot_start_falls_back_too(tmp_path: Path) -> None:
    (tmp_path / ".claude.json").write_text("{}", encoding="utf-8")

    def run(cmd: list[str], **_kwargs: Any) -> subprocess.CompletedProcess[str]:
        raise OSError("not a valid Win32 application")

    assert setup_claude_code(EXE, home=tmp_path, which=lambda: "claude", run=run).status == "configured"


OPENCODE_ENTRY = {"type": "local", "command": [str(EXE), "mcp"], "enabled": True}


def test_opencode_is_configured_in_its_global_config(tmp_path: Path) -> None:
    """OpenCode's own shape: servers under `mcp`, the command as a list (opencode.ai/docs/mcp-servers)."""
    folder = tmp_path / ".config" / "opencode"
    folder.mkdir(parents=True)
    (folder / "opencode.json").write_text(json.dumps({"$schema": "https://opencode.ai/config.json"}), encoding="utf-8")

    result = setup_opencode(EXE, home=tmp_path)

    assert result.status == "configured"
    assert _read(folder / "opencode.json") == {
        "$schema": "https://opencode.ai/config.json",
        "mcp": {SERVER_KEY: OPENCODE_ENTRY},
    }


def test_opencode_run_once_but_never_configured_gets_a_config(tmp_path: Path) -> None:
    """A first run creates its data folder, not always its config folder."""
    (tmp_path / ".local" / "share" / "opencode").mkdir(parents=True)

    result = setup_opencode(EXE, home=tmp_path)

    assert result.status == "configured"
    assert _read(tmp_path / ".config" / "opencode" / "opencode.json") == {"mcp": {SERVER_KEY: OPENCODE_ENTRY}}


def test_opencode_with_a_commented_jsonc_config_is_left_alone(tmp_path: Path) -> None:
    folder = tmp_path / ".config" / "opencode"
    folder.mkdir(parents=True)
    (folder / "opencode.jsonc").write_text('{\n  // mine\n  "theme": "x"\n}\n', encoding="utf-8")

    result = setup_opencode(EXE, home=tmp_path)

    assert result.status == "failed"
    assert (folder / "opencode.jsonc").read_text(encoding="utf-8") == '{\n  // mine\n  "theme": "x"\n}\n'
    assert not (folder / "opencode.json").exists()


def test_opencode_absent_is_not_found(tmp_path: Path) -> None:
    assert setup_opencode(EXE, home=tmp_path).status == "not_found"


def _toml(path: Path) -> Any:
    import tomllib

    return tomllib.loads(path.read_text(encoding="utf-8"))


def test_codex_gets_its_own_toml_section(tmp_path: Path) -> None:
    """Codex: `[mcp_servers.<name>]` in ~/.codex/config.toml, shared by the ChatGPT desktop app and the CLI."""
    (tmp_path / ".codex").mkdir()
    config = tmp_path / ".codex" / "config.toml"
    config.write_text('model = "gpt-5"\n\n[mcp_servers.other]\ncommand = "x"\n', encoding="utf-8")

    result = setup_codex(EXE, home=tmp_path)

    assert result.status == "configured"
    data = _toml(config)
    assert data["model"] == "gpt-5"
    assert data["mcp_servers"]["other"] == {"command": "x"}
    assert data["mcp_servers"][SERVER_KEY] == {"command": str(EXE), "args": ["mcp"]}


def test_codex_twice_replaces_its_section(tmp_path: Path) -> None:
    (tmp_path / ".codex").mkdir()
    setup_codex(Path(r"C:\old\veaf-tools.exe"), home=tmp_path)
    (tmp_path / ".codex" / "config.toml").write_text(
        (tmp_path / ".codex" / "config.toml").read_text(encoding="utf-8") + '\n[profiles.x]\nmodel = "y"\n',
        encoding="utf-8",
    )

    setup_codex(EXE, home=tmp_path)

    text = (tmp_path / ".codex" / "config.toml").read_text(encoding="utf-8")
    assert text.count(f"[mcp_servers.{SERVER_KEY}]") == 1
    data = _toml(tmp_path / ".codex" / "config.toml")
    assert data["mcp_servers"][SERVER_KEY]["command"] == str(EXE)
    assert data["profiles"]["x"] == {"model": "y"}


def test_codex_with_an_unreadable_config_is_left_alone(tmp_path: Path) -> None:
    (tmp_path / ".codex").mkdir()
    (tmp_path / ".codex" / "config.toml").write_text("model = \n", encoding="utf-8")

    assert setup_codex(EXE, home=tmp_path).status == "failed"
    assert (tmp_path / ".codex" / "config.toml").read_text(encoding="utf-8") == "model = \n"


def test_codex_absent_is_not_found(tmp_path: Path) -> None:
    assert setup_codex(EXE, home=tmp_path).status == "not_found"


def test_antigravity_is_configured_in_its_mcp_config(tmp_path: Path) -> None:
    """Antigravity: `mcpServers` in ~/.gemini/config/mcp_config.json (antigravity.google/docs/mcp)."""
    (tmp_path / ".gemini" / "antigravity-cli").mkdir(parents=True)

    result = setup_antigravity(EXE, home=tmp_path)

    assert result.status == "configured"
    assert _read(tmp_path / ".gemini" / "config" / "mcp_config.json") == {"mcpServers": {SERVER_KEY: ENTRY}}


def test_antigravity_absent_is_not_found(tmp_path: Path) -> None:
    (tmp_path / ".gemini").mkdir()

    assert setup_antigravity(EXE, home=tmp_path).status == "not_found"


def test_an_antigravity_folder_is_not_gemini_cli(tmp_path: Path) -> None:
    """Both live under ~/.gemini: Gemini CLI is the one with a settings.json."""
    (tmp_path / ".gemini" / "config").mkdir(parents=True)

    assert setup_gemini(EXE, home=tmp_path).status == "not_found"
