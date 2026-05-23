"""User global configuration for veaf-tools.

Reads ``~/veafmct.yaml`` (primary) or ``~/.veaf/config.yaml`` (fallback).
Settings in this file apply to **all** VEAF projects on this machine.

Resolution order for the configuration file:
1. ``~/veafmct.yaml``  — primary; explicit user choice
2. ``~/.veaf/config.yaml``  — VEAF-home fallback (created by older versions)
3. No file found → all defaults apply

Supported keys
--------------
``lang``
    CLI output language: ``en`` or ``fr``.
    Overridden by ``VEAF_LANG`` env var and ``--lang`` CLI flag.

``check_updates``
    Whether to check for newer releases on every interactive run.
    Default: ``true``.

``scripts_path``
    Default path to the VEAF-Mission-Creation-Tools repository root.
    Readable via ``get_scripts_path()``; used as a fallback in ``veaf-tools build``
    when neither the CLI ``--scripts-path`` flag nor ``mission.yaml`` provides a value.
    Default: ``null`` (auto-detect).

Example ``~/veafmct.yaml``::

    lang: fr
    check_updates: true
    scripts_path: ~/dev/VEAF/VEAF-Mission-Creation-Tools
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

_PRIMARY_CONFIG_NAME = "veafmct.yaml"
_FALLBACK_CONFIG_NAME = "config.yaml"

# Module-level cache — config is only read once per process.
_cache: dict[str, Any] | None = None


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _find_config_file() -> Path | None:
    """Return the first existing config file, or None."""
    primary = Path.home() / _PRIMARY_CONFIG_NAME
    if primary.exists():
        return primary
    try:
        from veaf_libs.veaf_home import get_veaf_home

        fallback = get_veaf_home() / _FALLBACK_CONFIG_NAME
        if fallback.exists():
            return fallback
    except Exception:
        pass
    return None


def _parse_yaml_file(path: Path) -> dict[str, Any]:
    """Parse a YAML file; return an empty dict on any error."""
    try:
        import yaml  # type: ignore[import-untyped]

        with path.open(encoding="utf-8") as fh:
            data = yaml.safe_load(fh)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def _load() -> dict[str, Any]:
    """Load and cache the user config.  Called lazily on first access."""
    global _cache
    if _cache is not None:
        return _cache
    path = config_file_path()
    _cache = _parse_yaml_file(path) if path is not None else {}
    return _cache


def _invalidate_cache() -> None:
    """Clear the module-level cache (test helper)."""
    global _cache
    _cache = None


def invalidate_cache() -> None:
    """Clear the cached configuration so the next access reloads from disk."""
    _invalidate_cache()


def get(key: str, default: Any = None) -> Any:
    """Return the value for *key* from the user config, or *default*."""
    return _load().get(key, default)


def get_lang() -> str | None:
    """Return the user-configured language code, or ``None`` if not set."""
    val = get("lang")
    if isinstance(val, str) and val.strip():
        return val.strip().lower()[:2]
    return None


def get_check_updates() -> bool:
    """Return whether the update check is enabled (default: ``True``)."""
    val = get("check_updates")
    return bool(val) if isinstance(val, bool) else True


def get_scripts_path() -> Path | None:
    """Return the configured scripts path, or ``None`` if not set."""
    val = get("scripts_path")
    if isinstance(val, str) and val.strip():
        return Path(val.strip()).expanduser()
    return None


def config_file_path() -> Path | None:
    """Return the path of the active config file, or ``None`` if none exists."""
    return _find_config_file()


def default_config_path() -> Path:
    """Return the canonical path for a new user config file (``~/veafmct.yaml``)."""
    return Path.home() / _PRIMARY_CONFIG_NAME


def set_value(key: str, value: Any) -> bool:
    """Persist *key*/*value* to the user config file.

    Creates ``~/veafmct.yaml`` if it does not yet exist.
    Returns ``True`` on success, ``False`` if the write failed.
    """
    try:
        import yaml  # type: ignore[import-untyped]

        path = config_file_path() or default_config_path()
        data = _parse_yaml_file(path) if path.exists() else {}
        data[key] = value
        path.write_text(yaml.dump(data, allow_unicode=True, default_flow_style=False), encoding="utf-8")
        _invalidate_cache()
        return True
    except Exception:
        return False


def unset_value(key: str) -> bool:
    """Remove *key* from the user config file.

    Returns ``True`` if the key existed and was removed, ``False`` otherwise.
    """
    try:
        import yaml  # type: ignore[import-untyped]

        path = config_file_path()
        if path is None or not path.exists():
            return False
        data = _parse_yaml_file(path)
        if key not in data:
            return False
        del data[key]
        path.write_text(yaml.dump(data, allow_unicode=True, default_flow_style=False), encoding="utf-8")
        _invalidate_cache()
        return True
    except Exception:
        return False
