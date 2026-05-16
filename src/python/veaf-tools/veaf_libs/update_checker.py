"""Update checker for veaf-tools.

Compares the running version against the latest GitHub release and prints a
Rich-formatted warning when a newer version is available.  All network errors
and timeouts are silently ignored so that offline use is never blocked.
"""

import json
import urllib.request
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from rich.console import Console

_GITHUB_RELEASES_URL = "https://api.github.com/repos/VEAF/VEAF-Mission-Creation-Tools/releases/latest"
_CHECK_TIMEOUT = 2  # seconds — do not block offline users


def check_for_updates(current_version: str, console: "Console") -> None:
    """Fetch the latest GitHub release and warn if a newer version exists.

    Args:
        current_version: The version string embedded in the running executable.
        console: Rich Console instance used to print the warning.
    """
    try:
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
        if latest and latest != current_version:
            console.print(
                f"[yellow]⚠ A newer version of veaf-tools is available: "
                f"[bold]{latest}[/bold] (you have {current_version})[/yellow]"
            )
            console.print("[yellow]  Run [bold]veaf-tools-updater update[/bold] to update.[/yellow]")
    except Exception:
        pass  # Offline, timeout, rate-limited — silently skip
