"""A bridge session: find or start dcs-serve, wait for the mission, stop what was started."""

from __future__ import annotations

from pathlib import Path

import pytest
from veaf_libs import dcs_bridge_session as session
from veaf_libs.dcs_bridge_capture import BridgeAuthError, BridgeHttpError, BridgeLuaError
from veaf_libs.dcs_bridge_session import BridgeSession, DcsServeMissing, open_session, wait_for_mission

URL = "http://127.0.0.1:8080"


class _FakeServer:
    def __init__(self, exe: Path, workdir: Path) -> None:
        self.exe, self.workdir = exe, workdir
        self.started_on: str | None = None
        self.stopped = False

    def start(self, serve_url: str) -> None:
        self.started_on = serve_url

    def stop(self) -> None:
        self.stopped = True


def test_a_running_server_is_used_with_the_key_of_our_own_folder(tmp_path: Path, monkeypatch) -> None:
    (tmp_path / "dcs-serve.yaml").write_text("api_key: OURS\n", encoding="utf-8")
    monkeypatch.setattr(session, "is_serving", lambda _url: True)
    opened = open_session(URL, workdir=tmp_path)
    assert (opened.key, opened.started) == ("OURS", None)


def test_an_explicit_key_wins_over_our_folder(tmp_path: Path, monkeypatch) -> None:
    (tmp_path / "dcs-serve.yaml").write_text("api_key: OURS\n", encoding="utf-8")
    monkeypatch.setattr(session, "is_serving", lambda _url: True)
    assert open_session(URL, api_key="THEIRS", workdir=tmp_path).key == "THEIRS"


def test_no_server_starts_one_with_a_generated_key(tmp_path: Path, monkeypatch) -> None:
    exe = tmp_path / "dcs-serve.exe"
    exe.write_bytes(b"")
    monkeypatch.setattr(session, "is_serving", lambda _url: False)
    monkeypatch.setattr(session, "DcsServe", _FakeServer)
    opened = open_session(URL, dcs_serve=str(exe), workdir=tmp_path / "serve")
    assert isinstance(opened.started, _FakeServer)
    assert opened.started.started_on == URL
    assert opened.key and opened.key in (tmp_path / "serve" / "dcs-serve.yaml").read_text(encoding="utf-8")


def test_no_server_and_nothing_to_start_says_where_to_find_one(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(session, "is_serving", lambda _url: False)
    monkeypatch.setattr(session, "find_dcs_serve", lambda _explicit: None)
    with pytest.raises(DcsServeMissing, match="veaf-map-capture-kit"):
        open_session(URL, workdir=tmp_path)


def test_close_stops_only_the_server_the_session_started() -> None:
    server = _FakeServer(Path("x"), Path("y"))
    BridgeSession(URL, "k", started=server).close()  # type: ignore[arg-type]
    assert server.stopped
    BridgeSession(URL, "k").close()  # nothing started, nothing to stop: no error


# --- wait_for_mission -----------------------------------------------------------------------------


class _Clock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.now += seconds


def _session_answering(replies: list) -> BridgeSession:
    """A session whose `run` raises or returns each of *replies* in turn."""
    opened = BridgeSession(URL, "k")

    def run(_code: str, timeout: float = 30.0) -> str:
        reply = replies.pop(0)
        if isinstance(reply, Exception):
            raise reply
        return reply

    opened.run = run  # type: ignore[method-assign]
    return opened


def test_wait_goes_through_no_mission_yet(monkeypatch) -> None:
    monkeypatch.setattr(session, "is_serving", lambda _url: True)
    clock = _Clock()
    replies = [BridgeHttpError(503, "no mission"), RuntimeError("504"), "ok"]
    wait_for_mission(_session_answering(replies), 60, clock=clock, sleep=clock.sleep, poll_seconds=2)
    assert clock.now == 4


def test_wait_refuses_a_refused_key_at_once() -> None:
    with pytest.raises(RuntimeError, match="refuses our key"):
        wait_for_mission(_session_answering([BridgeAuthError("401")]), 60, sleep=lambda _s: None)


def test_wait_refuses_another_program_on_the_port_at_once() -> None:
    with pytest.raises(RuntimeError, match="not a dcs-serve"):
        wait_for_mission(_session_answering([BridgeHttpError(404, "not found")]), 60, sleep=lambda _s: None)


def test_wait_refuses_a_lua_error_at_once() -> None:
    with pytest.raises(RuntimeError, match="the Lua raised"):
        wait_for_mission(_session_answering([BridgeLuaError("the Lua raised in the mission: x")]), 60)


def test_wait_stops_when_dcs_serve_is_gone(monkeypatch) -> None:
    monkeypatch.setattr(session, "is_serving", lambda _url: False)
    with pytest.raises(RuntimeError, match="no longer answers"):
        wait_for_mission(_session_answering([RuntimeError("cannot reach")]), 60, sleep=lambda _s: None)


def test_wait_gives_up_after_its_time_naming_what_it_last_saw() -> None:
    clock = _Clock()
    replies = [BridgeHttpError(503, "no mission yet")] * 10
    with pytest.raises(RuntimeError, match=r"after 5 s \(no mission yet\)"):
        wait_for_mission(_session_answering(replies), 5, clock=clock, sleep=clock.sleep, poll_seconds=2)
