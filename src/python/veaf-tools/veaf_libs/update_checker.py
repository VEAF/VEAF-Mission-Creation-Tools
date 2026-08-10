"""Update checker for veaf-tools.

Compares the running version against the latest GitHub release and prints a
Rich-formatted warning when a newer version is available.  All network errors
and timeouts are silently ignored so that offline use is never blocked.

The check result is cached for 24 hours in VEAF_HOME to avoid adding network
latency on every invocation.  The check is also skipped entirely when stdout
is not a TTY (scripted / piped use).
"""

import json
import sys
import urllib.request
from datetime import date
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from rich.console import Console

_GITHUB_RELEASES_URL = "https://api.github.com/repos/VEAF/VEAF-Mission-Creation-Tools/releases/latest"
_CHECK_TIMEOUT = 2  # seconds — do not block offline users
_CACHE_FILE = "update_check_cache.json"


#: What `_version_tuple` returns for a string it cannot read. Callers must recognise it rather than
#: compare it: it sorts below every real release (SECREV-2 / VMR-063).
_UNPARSEABLE_VERSION: tuple[int, ...] = (0,)


def _version_tuple(v: str) -> tuple[int, ...]:
    """Convert a dotted version string to a comparable integer tuple.

    Pre-release suffixes (e.g. ``-rc1``, ``-alpha``, ``-beta``) are stripped
    before parsing so that ``6.1.0-rc1`` compares as ``(6, 1, 0)``.
    """
    # Strip pre-release / build-metadata suffixes: "6.1.0-rc1" → "6.1.0"
    v = v.split("-")[0].split("+")[0]
    try:
        return tuple(int(x) for x in v.split("."))
    except ValueError:
        return _UNPARSEABLE_VERSION


def _load_cache(veaf_home: Path) -> dict:
    try:
        cache_file = veaf_home / _CACHE_FILE
        if cache_file.exists():
            return json.loads(cache_file.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {}


def _save_cache(veaf_home: Path, latest: str) -> None:
    try:
        cache = {"last_check": str(date.today()), "latest": latest}
        (veaf_home / _CACHE_FILE).write_text(json.dumps(cache), encoding="utf-8")
    except Exception:
        pass


def check_for_updates(current_version: str, console: "Console") -> None:
    """Fetch the latest GitHub release and warn if a newer version exists.

    The check is skipped when stdout is not a TTY (scripts, CI) and is
    cached for 24 hours in VEAF_HOME to avoid network latency on every call.

    Args:
        current_version: The version string embedded in the running executable.
        console: Rich Console instance used to print the warning.
    """
    # Skip entirely when not interactive (piped / scripted use)
    if not sys.stdout.isatty():
        return

    try:
        from veaf_libs.veaf_home import get_veaf_home

        veaf_home = get_veaf_home()
        cache = _load_cache(veaf_home)
        today = str(date.today())

        if cache.get("last_check") == today:
            # Use cached result — no network call needed today
            latest = cache.get("latest", "")
        else:
            req = urllib.request.Request(
                _GITHUB_RELEASES_URL,
                headers={
                    "Accept": "application/vnd.github.v3+json",
                    "User-Agent": f"veaf-tools/{current_version}",
                },
            )
            with urllib.request.urlopen(req, timeout=_CHECK_TIMEOUT) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            latest = data.get("tag_name", "").lstrip("v")
            _save_cache(veaf_home, latest)

        # A version we cannot parse must not be treated as "very old". `_version_tuple` falls back to
        # (0,), which is lower than every release, so an unreadable *current* version produced a
        # confident "a new version is available" on every single run (SECREV-2 / VMR-063). Saying
        # nothing is the honest answer when we do not know what is installed.
        current = _version_tuple(current_version)
        if current == _UNPARSEABLE_VERSION:
            return
        if latest and _version_tuple(latest) > current:
            from veaf_libs.i18n import t

            console.print(t("update.new_version", latest=latest, current=current_version))
            console.print(t("update.run_updater"))
    except Exception:
        pass  # Offline, timeout, rate-limited, or cache error — silently skip
