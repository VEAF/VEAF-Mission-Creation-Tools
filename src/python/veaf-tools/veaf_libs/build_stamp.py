"""Resolve the veaf-tools build stamp (package version + git commit) for traceability.

The build stamp is what lets a maintainer tell, from a tester's DCS log alone, which
exact code built a mission. The package version only changes at release; the git commit
short SHA disambiguates the dev builds testers run *between* releases.

Resolution order for the commit SHA:

1. ``veaf_tools._version.__commit__`` — baked in when the binary is packaged by
   ``veaf-build`` (the only reliable source for a standalone binary, which has no git
   repository around it).
2. ``git rev-parse --short HEAD`` — for editable/dev installs running inside the repo.
3. empty — the stamp degrades to the bare package version.
"""

from __future__ import annotations

import subprocess
from importlib.metadata import PackageNotFoundError
from importlib.metadata import version as _pkg_version


def _package_version() -> str:
    """Return the veaf-tools package version, or ``"unknown"`` if it cannot be resolved."""
    try:
        return _pkg_version("veaf-tools")
    except PackageNotFoundError:
        try:
            from veaf_tools._version import __version__

            return __version__
        except ImportError:
            return "unknown"


def _commit() -> str:
    """Return the short git commit SHA that built this tool, or ``""`` if unavailable."""
    try:
        from veaf_tools._version import __commit__

        if __commit__:
            return __commit__
    except (ImportError, AttributeError):
        pass
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return ""


def get_build_stamp() -> str:
    """Build the human-facing build stamp.

    Returns:
        ``"<version>+<sha>"`` when a commit SHA is available, otherwise the bare package
        version (e.g. ``"6.7.3+5815cbab"`` or ``"6.7.3"``).
    """
    version = _package_version()
    commit = _commit()
    return f"{version}+{commit}" if commit else version
