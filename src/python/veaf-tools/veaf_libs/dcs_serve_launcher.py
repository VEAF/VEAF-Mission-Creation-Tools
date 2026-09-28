"""Start ``dcs-serve`` for a command that needs it, with a key of its own, and stop it afterwards.

``dcs-serve`` is the small local server of the VEAF dcs-bridge: the ``dcs-bridge.lua`` script embedded
in a mission connects to it, and ``veaf-tools`` sends its Lua through it (``POST /api/exec``). It reads
its configuration — ports, and the API key a client must present — from a ``dcs-serve.yaml`` **in its
working directory**, and generates a key there when the file has none.

So owning the working directory is owning the key: this module gives ``dcs-serve`` a folder of its
own, writes a ``dcs-serve.yaml`` holding a freshly generated key and listening on the loopback only,
and hands that key to the caller. Nobody copies a key by hand, and a server started this way is not
reachable from the network — the one it would otherwise open by default on ``0.0.0.0`` carries a
superuser Lua-execution endpoint.
"""

from __future__ import annotations

import os
import secrets
import shutil
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import IO
from urllib.parse import urlparse

import yaml

_EXE_NAME = "dcs-serve.exe" if sys.platform == "win32" else "dcs-serve"


def is_serving(serve_url: str, timeout: float = 2.0) -> bool:
    """Tell whether a ``dcs-serve`` answers at *serve_url*, whatever it answers.

    A 401 or a 503 is a server that is up — refusing a request without a key, or waiting for a
    mission; only a refused connection means there is none.

    Args:
        serve_url: The server's base URL.
        timeout: Seconds to wait for an answer.

    Returns:
        True when something answers HTTP there.
    """
    try:
        with urllib.request.urlopen(f"{serve_url.rstrip('/')}/api/capabilities", timeout=timeout):  # noqa: S310
            return True
    except urllib.error.HTTPError:
        return True
    except (urllib.error.URLError, TimeoutError, OSError):
        return False


def find_dcs_serve(explicit: str | None = None) -> Path | None:
    """Find the ``dcs-serve`` executable: given, next to this program (the capture kit), or on ``PATH``.

    Args:
        explicit: A path the user gave, which must exist.

    Returns:
        The executable, or ``None`` when none is found.
    """
    if explicit:
        path = Path(explicit)
        return path if path.is_file() else None
    if getattr(sys, "frozen", False):
        beside = Path(sys.executable).parent / _EXE_NAME
        if beside.is_file():
            return beside
    found = shutil.which(_EXE_NAME) or shutil.which("dcs-serve")
    return Path(found) if found else None


def ensure_config(workdir: Path, serve_url: str) -> tuple[Path, str]:
    """Write, or reuse, the ``dcs-serve.yaml`` of *workdir*; return its path and API key.

    An existing key is kept, so a server restarted in the same folder keeps the key a client already
    holds.

    Args:
        workdir: The server's working directory.
        serve_url: Where the server must listen; its port is written into the configuration.

    Returns:
        The configuration file and the API key it holds.
    """
    workdir.mkdir(parents=True, exist_ok=True)
    path = workdir / "dcs-serve.yaml"
    existing = yaml.safe_load(path.read_text(encoding="utf-8")) if path.is_file() else None
    config = existing if isinstance(existing, dict) else {}
    key = str(config.get("api_key") or secrets.token_hex(24))
    config.update(
        {
            "api_key": key,
            "http_host": "127.0.0.1",
            "http_port": urlparse(serve_url).port or 8080,
            "tcp_host": "127.0.0.1",
            "tcp_port": int(config.get("tcp_port") or 7777),
        }
    )
    path.write_text(yaml.safe_dump(config, sort_keys=True), encoding="utf-8")
    return path, key


class DcsServe:
    """A ``dcs-serve`` this program started, stopped on :meth:`stop`.

    Args:
        exe: The executable.
        workdir: Its working directory, which holds its ``dcs-serve.yaml`` and its log.
    """

    def __init__(self, exe: Path, workdir: Path) -> None:
        self.exe = exe
        self.workdir = workdir
        self.log_path = workdir / "dcs-serve.log"
        self._log: IO[bytes] | None = None
        self._process: subprocess.Popen[bytes] | None = None

    def start(self, serve_url: str, timeout: float = 15.0) -> None:
        """Start the server and wait until it answers.

        Raises:
            RuntimeError: If it exits, or does not answer within *timeout* seconds.
        """
        self._log = self.log_path.open("wb")
        self._process = subprocess.Popen(  # noqa: S603 - a local executable the user pointed at or shipped with us
            [str(self.exe)],
            cwd=self.workdir,
            stdout=self._log,
            stderr=subprocess.STDOUT,
            # Its own process group off Windows, so `stop` can end the whole tree.
            start_new_session=sys.platform != "win32",
        )
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self._process.poll() is not None:
                self.stop()  # closes the log, which the caller would otherwise find locked
                raise RuntimeError(
                    f"dcs-serve stopped at once (exit code {self._process.returncode}); see {self.log_path}"
                )
            if is_serving(serve_url, timeout=1.0):
                return
            time.sleep(0.5)
        self.stop()
        raise RuntimeError(f"dcs-serve did not answer on {serve_url} within {timeout:.0f} s; see {self.log_path}")

    def stop(self) -> None:
        """Stop the server and every process it started, if it runs.

        The whole tree, not the process alone: ``dcs-serve.exe`` is a PyInstaller one-file build,
        whose bootloader runs the real server as a child. ``terminate()`` stopped the bootloader and
        left the server running, measured on 2026-09-28 — still answering, with its key, after the
        command had said it was stopped, and the next run took it for somebody else's.
        """
        if self._process is not None and self._process.poll() is None:
            if sys.platform == "win32":
                subprocess.run(  # noqa: S603 - fixed system tool, our own pid
                    ["taskkill", "/PID", str(self._process.pid), "/T", "/F"],  # noqa: S607
                    capture_output=True,
                    check=False,
                )
            else:
                os.killpg(self._process.pid, signal.SIGTERM)
            try:
                self._process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self._process.kill()
        if self._log is not None:
            self._log.close()
            self._log = None
