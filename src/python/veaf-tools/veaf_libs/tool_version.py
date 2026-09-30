"""The version of veaf-tools, readable without loading the command line.

It used to live in ``veaf_tools.app``, which imports every command and, through them, the MCP
server stack. ``veaf_libs.diagnostics`` reads the version for its report, and ``veaf-logs`` builds
that report — so the log viewer's executable carried the whole CLI to read one string
(CHORE-LOGS-EXE-TRIM). ``veaf_tools.app`` re-exports :data:`VERSION`, so its importers are unchanged.
"""

from importlib.metadata import PackageNotFoundError
from importlib.metadata import version as _pkg_version

try:
    VERSION: str = _pkg_version("veaf-tools")
except PackageNotFoundError:
    try:
        from veaf_tools._version import __version__ as _fallback

        VERSION = _fallback
    except ImportError:
        VERSION = "unknown"
