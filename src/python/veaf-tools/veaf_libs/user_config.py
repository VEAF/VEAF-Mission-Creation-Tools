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

``servers``
    DCS servers whose logs ``veaf-logs`` can open over SSH. A mapping of server
    name to ``host`` (required), ``user`` (required), ``port`` (default 22),
    ``key`` (optional private key path; the SSH agent and the default keys are
    tried otherwise) and ``logs`` — a mapping of instance name to the remote
    path of its ``dcs.log``. Readable via ``get_servers()``. Never a password:
    authentication is by key only.

Example ``~/veafmct.yaml``::

    lang: fr
    check_updates: true
    scripts_path: ~/dev/VEAF/VEAF-Mission-Creation-Tools
    servers:
      veaf:
        host: dcs.veaf.org
        user: veaf
        key: ~/.ssh/id_ed25519
        logs:
          private1: C:/Users/veaf/Saved Games/private1_server/Logs/dcs.log
"""

from __future__ import annotations

from dataclasses import dataclass, field
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


@dataclass(frozen=True)
class RemoteServer:
    """A DCS server reachable over SSH, with the logs it hosts.

    ``logs`` maps an instance name (``private1``) to the remote path of that
    instance's ``dcs.log``. One machine runs several DCS instances, so the
    machine is declared once and each instance names its own log. Each open
    log holds its own SSH connection: they are cheap (0.4 s measured) and an
    outage on one tab then never disturbs the others.
    """

    name: str
    host: str
    user: str
    port: int = 22
    key: Path | None = None
    logs: dict[str, str] = field(default_factory=dict)


def _parse_server(name: str, raw: Any) -> RemoteServer:
    """Build a ``RemoteServer`` from one ``servers`` entry, or raise ``ValueError``."""
    if not isinstance(raw, dict):
        raise ValueError(f"servers.{name}: expected a mapping (host, user, logs…)")
    for required in ("host", "user"):
        value = raw.get(required)
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"servers.{name}.{required}: required, non-empty string")
    port = raw.get("port", 22)
    if isinstance(port, bool) or not isinstance(port, int) or not 1 <= port <= 65535:
        raise ValueError(f"servers.{name}.port: expected an integer between 1 and 65535")
    key_raw = raw.get("key")
    key: Path | None = None
    if key_raw is not None:
        if not isinstance(key_raw, str) or not key_raw.strip():
            raise ValueError(f"servers.{name}.key: expected a path")
        key = Path(key_raw.strip()).expanduser()
    logs = raw.get("logs")
    if not isinstance(logs, dict) or not logs:
        raise ValueError(f"servers.{name}.logs: expected a non-empty mapping of instance name to log path")
    for instance, path in logs.items():
        if not isinstance(path, str) or not path.strip():
            raise ValueError(f"servers.{name}.logs.{instance}: expected a remote path")
    return RemoteServer(
        name=str(name),
        host=raw["host"].strip(),
        user=raw["user"].strip(),
        port=port,
        key=key,
        logs={str(instance): path.strip() for instance, path in logs.items()},
    )


def get_servers() -> list[RemoteServer]:
    """Return the configured DCS servers, in declaration order.

    Returns:
        The parsed ``servers`` entries; an empty list when the block is absent.

    Raises:
        ValueError: when the block or one of its entries is malformed. The
            message names the offending key so the user can fix the file.
    """
    raw = get("servers")
    if raw is None:
        return []
    if not isinstance(raw, dict):
        raise ValueError("servers: expected a mapping of server name to settings")
    return [_parse_server(str(name), value) for name, value in raw.items()]


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
