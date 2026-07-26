"""Tests for the shared dcs-bridge airbase capture/injection helpers."""

from __future__ import annotations

import json
import urllib.error
from pathlib import Path
from unittest import mock

import pytest
from veaf_libs import dcs_bridge_capture as C


def _fake_resp(payload: dict[str, object]) -> mock.MagicMock:
    """A urlopen() context manager whose .read() yields *payload* as JSON."""
    m = mock.MagicMock()
    m.read.return_value = json.dumps(payload).encode("utf-8")
    m.__enter__.return_value = m
    m.__exit__.return_value = False
    return m


# --- resolve_bridge_lua ----------------------------------------------------


def test_resolve_bridge_lua_local(tmp_path: Path) -> None:
    f = tmp_path / "dcs-bridge.lua"
    f.write_text("-- bridge", encoding="utf-8")
    assert C.resolve_bridge_lua(str(f)) == f


def test_resolve_bridge_lua_missing_raises(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        C.resolve_bridge_lua(str(tmp_path / "nope.lua"))


# --- resolve_api_key ------------------------------------------------------


def test_resolve_api_key_explicit_wins(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    (tmp_path / "dcs-serve.yaml").write_text("api_key: FROM_FILE\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    assert C.resolve_api_key("EXPLICIT") == "EXPLICIT"


def test_resolve_api_key_reads_cwd_config(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    (tmp_path / "dcs-serve.yaml").write_text("api_key: FROM_SERVE\ntcp_port: 7777\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    assert C.resolve_api_key() == "FROM_SERVE"


def test_resolve_api_key_falls_back_to_client_config(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    (tmp_path / "dcs-client.yaml").write_text('api_key: "FROM_CLIENT"\n', encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    assert C.resolve_api_key() == "FROM_CLIENT"


def test_resolve_api_key_explicit_config_path(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cfg = tmp_path / "elsewhere.yaml"
    cfg.write_text("api_key: FROM_ARG\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path.parent)
    assert C.resolve_api_key(None, str(cfg)) == "FROM_ARG"


def test_resolve_api_key_missing_config_raises(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        C.resolve_api_key(None, str(tmp_path / "nope.yaml"))


def test_resolve_api_key_config_without_key_raises(tmp_path: Path) -> None:
    cfg = tmp_path / "dcs-serve.yaml"
    cfg.write_text("tcp_port: 7777\n", encoding="utf-8")
    with pytest.raises(RuntimeError, match="no 'api_key' field"):
        C.resolve_api_key(None, str(cfg))


def test_resolve_api_key_not_found_explains_how_to_fix(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(tmp_path)  # empty dir: no config anywhere
    with pytest.raises(RuntimeError, match="start dcs-serve once"):
        C.resolve_api_key()


# --- capture_airbases (parses the tab-separated snippet result) ------------

_RESULT = "Syria\n1\tAbu al-Duhur\t35.731462\t37.118802\t0\n39\tTiyas\t34.522725\t37.61448\t2"


def test_capture_parses_theatre_and_records() -> None:
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": _RESULT})):
        theatre, airbases = C.capture_airbases("http://127.0.0.1:8080", "key")
    assert theatre == "Syria"
    assert airbases[0] == {"id": 1, "name": "Abu al-Duhur", "lat": 35.731462, "lon": 37.118802, "coalition": 0}
    assert airbases[1] == {"id": 39, "name": "Tiyas", "lat": 34.522725, "lon": 37.61448, "coalition": 2}


def test_capture_raises_on_lua_error() -> None:
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": "Error: boom"})):
        with pytest.raises(RuntimeError, match="bridge exec failed"):
            C.capture_airbases("http://127.0.0.1:8080", "key")


def test_capture_raises_when_unreachable() -> None:
    with mock.patch("urllib.request.urlopen", side_effect=urllib.error.URLError("refused")):
        with pytest.raises(RuntimeError, match="cannot reach dcs-serve"):
            C.capture_airbases("http://127.0.0.1:8080", "key")


def test_capture_raises_clear_message_on_504() -> None:
    err = urllib.error.HTTPError("http://x/api/exec", 504, "Gateway Timeout", {}, None)  # type: ignore[arg-type]
    with mock.patch("urllib.request.urlopen", side_effect=err):
        with pytest.raises(RuntimeError, match="no reply from DCS"):
            C.capture_airbases("http://127.0.0.1:8080", "key")


def test_capture_raises_on_client_timeout() -> None:
    with mock.patch("urllib.request.urlopen", side_effect=TimeoutError("timed out")):
        with pytest.raises(RuntimeError, match="cannot reach dcs-serve"):
            C.capture_airbases("http://127.0.0.1:8080", "key")


# --- write_airbase_dump ----------------------------------------------------


def test_write_airbase_dump_writes_json(tmp_path: Path) -> None:
    airbases = [{"id": 39, "name": "Tiyas", "lat": 34.5, "lon": 37.6, "coalition": 0}]
    out = C.write_airbase_dump("Syria", airbases, tmp_path)
    assert out.name == "Syria.json"
    doc = json.loads(out.read_text(encoding="utf-8"))
    assert doc["theatre"] == "Syria"
    assert doc["airbases"][0]["name"] == "Tiyas"


# --- inject_bridge (thin wrapper over the editor-parity primitive) ---------


def test_inject_bridge_calls_primitive_in_file_static_mode(tmp_path: Path) -> None:
    lua = tmp_path / "dcs-bridge.lua"
    lua.write_text("-- bridge", encoding="utf-8")
    target = "veaf_mission_mcp.add_startup_script_trigger.add_startup_script_trigger"
    with mock.patch(target, return_value={"trigger_index": 1, "comment": "dcs-bridge loading"}) as m:
        res = C.inject_bridge(tmp_path / "m.miz", lua)
    kwargs = m.call_args.kwargs
    assert kwargs["mode"] == "file_static"
    assert kwargs["resource_name"] == "dcs-bridge.lua"
    assert kwargs["comment"] == "dcs-bridge loading"
    assert res["trigger_index"] == 1
