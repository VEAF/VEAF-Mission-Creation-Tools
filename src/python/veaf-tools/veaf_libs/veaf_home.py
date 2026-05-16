"""VEAF home directory management.

The VEAF home directory (~/.veaf/ by default, overridable via the VEAF_HOME
environment variable) is the centralized location for user-specific data:
logs, preferences, cached files, and installed Lua scripts.
"""

import os
from pathlib import Path

_VEAF_HOME_ENV = "VEAF_HOME"
_VEAF_HOME_DEFAULT = Path.home() / ".veaf"


def get_veaf_home() -> Path:
    """Return the VEAF home directory, creating it if it does not exist.

    Resolution order:
    1. ``$VEAF_HOME`` environment variable (if set and non-empty)
    2. ``~/.veaf/`` (default)
    """
    home_str = os.environ.get(_VEAF_HOME_ENV, "").strip()
    home = Path(home_str) if home_str else _VEAF_HOME_DEFAULT
    home.mkdir(parents=True, exist_ok=True)
    return home
