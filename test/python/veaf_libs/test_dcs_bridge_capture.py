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


# --- exec_over_bridge: a Lua error is an error -------------------------------
#
# `dcs-serve` answers a chunk that raised with HTTP 200 and `{"error": …}` and no `result`. Read as a
# result, that was an empty string — a check comparing it to an expected value failed with "returned
# ''" instead of naming the Lua error, and a caller that accepts "" took it for success.


def test_exec_over_bridge_raises_the_lua_error() -> None:
    reply = {"error": "[string \"return nope.x\"]:1: attempt to index global 'nope'"}
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp(reply)):
        with pytest.raises(C.BridgeLuaError, match="attempt to index global 'nope'"):
            C.exec_over_bridge("http://127.0.0.1:8080", "key", "return nope.x")


def test_exec_over_bridge_returns_an_empty_result_as_empty() -> None:
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": ""})):
        assert C.exec_over_bridge("http://127.0.0.1:8080", "key", "return nil") == ""


# --- exec_in_state: another Lua state, through net.dostring_in ---------------


def test_in_state_lua_sends_the_chunk_quoted_to_the_named_state() -> None:
    lua = C.in_state_lua("export", 'return "a\\nb"')
    assert lua == 'return net.dostring_in("export", "return \\"a\\\\nb\\"")'


def test_exec_in_state_returns_what_the_state_returned() -> None:
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": "ok"})) as m:
        assert C.exec_in_state("http://127.0.0.1:8080", "key", "export", "return 'ok'") == "ok"
    sent = json.loads(m.call_args.args[0].data)
    assert sent["code"].startswith('return net.dostring_in("export",')


def test_exec_in_state_raises_a_lua_error_handed_back_as_the_result() -> None:
    """`net.dostring_in` returns the target state's error *as its string result*, shaped like success."""
    error = '[string "LoSetCameraPosition(nil)"]:1: bad argument #1'
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": error})):
        with pytest.raises(C.BridgeLuaError, match="in the export state"):
            C.exec_in_state("http://127.0.0.1:8080", "key", "export", "LoSetCameraPosition(nil)")


def test_exec_in_state_raises_the_short_form_of_a_lua_error() -> None:
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": ":1: attempt to call nil"})):
        with pytest.raises(C.BridgeLuaError):
            C.exec_in_state("http://127.0.0.1:8080", "key", "gui", "nope()")


# --- write_airbase_dump ----------------------------------------------------


def test_write_airbase_dump_writes_json(tmp_path: Path) -> None:
    airbases = [{"id": 39, "name": "Tiyas", "lat": 34.5, "lon": 37.6, "coalition": 0}]
    out = C.write_airbase_dump("Syria", airbases, tmp_path)
    assert out.name == "Syria.json"
    doc = json.loads(out.read_text(encoding="utf-8"))
    assert doc["theatre"] == "Syria"
    assert doc["airbases"][0]["name"] == "Tiyas"


# --- capture_parking -------------------------------------------------------
#
# Placing an aircraft on a *stand* rather than at coordinates needs the airfield's slot ids, and a
# parked unit in a real mission carries **two** distinct numbers (`parking` 28 with `parking_id` 24
# on the same aircraft — `Term_Index` and `Term_Index_0`). Neither can be invented, and the API
# schema shipped here declares four fields where the runtime returns more, so the snippet dumps
# **every** key it finds and these tests pin that pass-through rather than a chosen field list.

_PARKING_RESULT = (
    "Caucasus\n"
    "12\tTerm_Index=28|Term_Index_0=24|Term_Type=104|vTerminalPos.x=-1000.5|vTerminalPos.z=2000.5\n"
    "12\tTerm_Index=29|Term_Index_0=25|Term_Type=104\n"
    "13\tTerm_Index=1|Term_Index_0=1|Term_Type=40"
)


def test_capture_parking_groups_slots_by_airbase() -> None:
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": _PARKING_RESULT})):
        theatre, slots = C.capture_parking("http://127.0.0.1:8080", "key")
    assert theatre == "Caucasus"
    assert sorted(slots) == [12, 13]
    assert len(slots[12]) == 2


def test_capture_parking_keeps_both_terminal_indices() -> None:
    """The pair is the whole point: they differ, and a mission needs both to park a unit."""
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": _PARKING_RESULT})):
        _, slots = C.capture_parking("http://127.0.0.1:8080", "key")
    assert (slots[12][0]["Term_Index"], slots[12][0]["Term_Index_0"]) == ("28", "24")


def test_capture_parking_keeps_a_flattened_nested_field() -> None:
    """A slot's position arrives as a nested table; flattened one level, it survives."""
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": _PARKING_RESULT})):
        _, slots = C.capture_parking("http://127.0.0.1:8080", "key")
    assert slots[12][0]["vTerminalPos.x"] == "-1000.5"


def test_capture_parking_keeps_keys_it_was_not_written_for() -> None:
    """Forward compatibility: an unknown key must survive, since the schema is known incomplete."""
    result = "Caucasus\n12\tTerm_Index=1|SomeFutureField=yes"
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": result})):
        _, slots = C.capture_parking("http://127.0.0.1:8080", "key")
    assert slots[12][0]["SomeFutureField"] == "yes"


def test_capture_parking_raises_on_lua_error() -> None:
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": "Error: boom"})):
        with pytest.raises(RuntimeError, match="bridge exec failed"):
            C.capture_parking("http://127.0.0.1:8080", "key")


def test_capture_parking_accepts_a_theatre_with_no_slots_at_all() -> None:
    """A WWII map's airfields may report none; that is data, not a failure."""
    with mock.patch("urllib.request.urlopen", return_value=_fake_resp({"result": "Normandy"})):
        theatre, slots = C.capture_parking("http://127.0.0.1:8080", "key")
    assert (theatre, slots) == ("Normandy", {})


def test_write_parking_dump_keys_by_airbase_id(tmp_path: Path) -> None:
    out = C.write_parking_dump("Caucasus", {13: [{"Term_Index": "1"}], 12: [{"Term_Index": "28"}]}, tmp_path)
    doc = json.loads(out.read_text(encoding="utf-8"))
    assert list(doc["parking_by_airbase"]) == ["12", "13"]


def test_write_parking_dump_names_the_file_after_the_theatre(tmp_path: Path) -> None:
    out = C.write_parking_dump("Caucasus", {12: [{"Term_Index": "28"}]}, tmp_path)
    assert out.name == "Caucasus.json"


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
