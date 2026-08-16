"""The fiddle hook's per-session auth, client side — FIX-SECREV2-EXPIRED-DEFERRALS ticket 02.

The vendored hook (omltcat/dcs-lua-runner) generates a fresh Basic-auth password at each launch, writes
it to a file, and requires it on every request (the local bypass is off). This client reads that file
and sends the credential. The Lua half is validated by a live run (a credential that silently breaks the
transport is the trap ADR 0019 refused to ship blind); what is unit-tested here is that the client
resolves the password from the right places and sends it as HTTP Basic, and that a rejection reads as a
rejection rather than as a missing hook.
"""

from __future__ import annotations

import base64
import io
import json
import re
import urllib.error
from pathlib import Path
from typing import Any

import pytest
from veaf_libs import dcs_fiddle_client as client
from veaf_libs.dcs_fiddle_client import (
    ENV_FIDDLE_TOKEN,
    FIDDLE_USERNAME,
    FiddleError,
    exec_lua,
    resolve_fiddle_token,
    set_session_token,
)


@pytest.fixture(autouse=True)
def _reset_session_token() -> Any:
    """Keep the process-wide password from leaking between tests."""
    set_session_token(None)
    yield
    set_session_token(None)


class _FakeResponse(io.BytesIO):
    def __enter__(self) -> _FakeResponse:
        return self

    def __exit__(self, *_: object) -> None:
        self.close()


def _capture_auth(monkeypatch: pytest.MonkeyPatch) -> list[str | None]:
    """Install a fake hook that records the Authorization header of each request."""
    seen: list[str | None] = []

    def fake_urlopen(request: Any, timeout: float = 0.0) -> _FakeResponse:
        seen.append(request.get_header("Authorization"))
        return _FakeResponse(json.dumps({"result": "ok"}).encode("utf-8"))

    monkeypatch.setattr(client.urllib.request, "urlopen", fake_urlopen)
    return seen


def _expected_header(password: str) -> str:
    raw = f"{FIDDLE_USERNAME}:{password}".encode()
    return "Basic " + base64.b64encode(raw).decode("ascii")


class TestResolveToken:
    def test_explicit_wins(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv(ENV_FIDDLE_TOKEN, "from-env")
        assert resolve_fiddle_token("explicit") == "explicit"

    def test_env_var_used_when_no_explicit(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv(ENV_FIDDLE_TOKEN, "from-env")
        assert resolve_fiddle_token() == "from-env"

    def test_file_read_when_no_explicit_or_env(self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
        monkeypatch.delenv(ENV_FIDDLE_TOKEN, raising=False)
        token_file = tmp_path / "dcs-fiddle-token.txt"
        token_file.write_text("  abc123\n", encoding="utf-8")
        assert resolve_fiddle_token(path=token_file) == "abc123"

    def test_none_when_file_absent(self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
        monkeypatch.delenv(ENV_FIDDLE_TOKEN, raising=False)
        assert resolve_fiddle_token(path=tmp_path / "does-not-exist.txt") is None

    def test_empty_file_is_none_not_empty_string(self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
        monkeypatch.delenv(ENV_FIDDLE_TOKEN, raising=False)
        token_file = tmp_path / "dcs-fiddle-token.txt"
        token_file.write_text("   \n", encoding="utf-8")
        assert resolve_fiddle_token(path=token_file) is None


class TestCredentialsAreSent:
    def test_no_token_means_no_auth_header(self, monkeypatch: pytest.MonkeyPatch) -> None:
        seen = _capture_auth(monkeypatch)
        exec_lua("return 1")
        assert seen == [None]

    def test_session_token_is_sent_as_basic_auth(self, monkeypatch: pytest.MonkeyPatch) -> None:
        seen = _capture_auth(monkeypatch)
        set_session_token("s3cr3t")
        exec_lua("return 1")
        assert seen[0] == _expected_header("s3cr3t")

    def test_explicit_token_overrides_the_session_one(self, monkeypatch: pytest.MonkeyPatch) -> None:
        seen = _capture_auth(monkeypatch)
        set_session_token("session")
        exec_lua("return 1", token="explicit")
        assert seen[0] == _expected_header("explicit")

    def test_username_is_veaf(self) -> None:
        # The vendored hook checks FIDDLE.USERNAME = 'veaf'; the two must agree.
        assert FIDDLE_USERNAME == "veaf"


class TestRejectionIsReadable:
    def test_401_names_the_credentials_not_a_missing_hook(self, monkeypatch: pytest.MonkeyPatch) -> None:
        def fake_urlopen(request: Any, timeout: float = 0.0) -> _FakeResponse:
            raise urllib.error.HTTPError(request.full_url, 401, "Unauthorized", {}, None)  # type: ignore[arg-type]

        monkeypatch.setattr(client.urllib.request, "urlopen", fake_urlopen)
        with pytest.raises(FiddleError, match="rejected the credentials"):
            exec_lua("return 1")


class TestTheHookDoesNotClobberTheFramework:
    """The hook must not declare a global named `veaf` (FIX-FIDDLE-HOOK-CLOBBERS-VEAF).

    It is injected into the MISSION scripting environment — the same Lua state the VEAF framework
    lives in — and it is injected *after* the mission scripts have loaded. Measured in game on
    2026-08-16: `veaf = {}` at the top of the hook replaced the whole framework table 16 seconds
    into the mission, so `veaf.loggers` and `veaf.ctldLogLevels` became nil, every VEAF event
    handler started raising, and CTLD's `onPlayerEnterUnit` died before building the player's radio
    menu — reported as "no CTLD menu", 400 lines and one wrong suspect away from its cause.

    A grep is a crude guard, but the failure it prevents is invisible until someone flies the
    mission, and the hook is a vendored file that gets re-synced from upstream.
    """

    HOOK = Path(__file__).resolve().parents[3] / "src" / "scripts" / "other" / "dcs-fiddle-server.lua"

    def test_the_hook_file_exists_where_the_guard_expects_it(self) -> None:
        # A moved file would make the assertion below vacuously true.
        assert self.HOOK.is_file(), f"vendored hook not found at {self.HOOK}"

    def test_no_global_veaf_assignment(self) -> None:
        offenders = [
            f"line {n}: {line.strip()}"
            for n, line in enumerate(self.HOOK.read_text(encoding="utf-8").splitlines(), 1)
            if re.match(r"^\s*veaf\s*=", line)
        ]
        assert offenders == [], (
            "the hook assigns the global `veaf`, which replaces the VEAF framework table in the "
            "mission scripting environment — use `veafFiddle` instead:\n  " + "\n  ".join(offenders)
        )

    def test_no_field_written_on_a_global_veaf_table(self) -> None:
        offenders = [
            f"line {n}: {line.strip()}"
            for n, line in enumerate(self.HOOK.read_text(encoding="utf-8").splitlines(), 1)
            if re.match(r"^\s*function\s+veaf\.", line)
        ]
        assert offenders == [], "the hook defines functions on the framework's `veaf` table:\n  " + "\n  ".join(
            offenders
        )
