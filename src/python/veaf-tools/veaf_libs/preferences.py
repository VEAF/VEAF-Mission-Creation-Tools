"""User preferences persistence for veaf-tools.

Stores the last command and its arguments in VEAF_HOME so the TUI wizard can
pre-fill fields on the next run.  All I/O errors are silently ignored — preferences
are a convenience feature and must never break normal operation.
"""

import json
from typing import Any

from veaf_libs.veaf_home import get_veaf_home

_PREFS_FILE = "preferences.json"


def load_preferences() -> dict[str, Any]:
    """Load preferences from VEAF_HOME.  Returns an empty dict on any error."""
    try:
        prefs_file = get_veaf_home() / _PREFS_FILE
        if prefs_file.exists():
            return json.loads(prefs_file.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {}


def save_preferences(prefs: dict[str, Any]) -> None:
    """Persist preferences to VEAF_HOME.  Silently ignored on any error."""
    try:
        prefs_file = get_veaf_home() / _PREFS_FILE
        prefs_file.write_text(json.dumps(prefs, indent=2, ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass


def get_last_command() -> str:
    """Return the name of the last invoked command, or empty string."""
    return load_preferences().get("last_command", "")


def get_last_args(command: str) -> dict[str, Any]:
    """Return the saved arguments for *command*, or an empty dict."""
    return load_preferences().get("last_args", {}).get(command, {})


def save_invocation(command: str, args: dict[str, Any]) -> None:
    """Record that *command* was invoked with *args*."""
    prefs = load_preferences()
    prefs["last_command"] = command
    last_args: dict[str, Any] = prefs.setdefault("last_args", {})
    last_args[command] = args
    save_preferences(prefs)
