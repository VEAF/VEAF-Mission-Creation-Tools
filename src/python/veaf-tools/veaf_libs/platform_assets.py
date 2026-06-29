"""Map the current OS/arch to VEAF binary file names and release asset names.

PyInstaller produces one binary per OS/arch; the release ships them as
``veaf-tools-<os>-<arch>`` / ``veaf-tools-updater-<os>-<arch>`` assets (see the
FEAT-CROSSPLATFORM-BINARIES lot). This module is the single source of truth the
updater uses at runtime to pick the asset matching the machine it runs on. The CI
release matrix mirrors the same three suffixes.

All functions accept optional ``system`` / ``machine`` overrides (defaulting to the
live :mod:`platform` values) so the mapping is testable across platforms.
"""

from __future__ import annotations

import platform

#: (lowercased system, normalized machine) -> release asset suffix.
_SUFFIXES: dict[tuple[str, str], str] = {
    ("linux", "x86_64"): "linux-x86_64",
    ("darwin", "arm64"): "macos-arm64",
    ("darwin", "x86_64"): "macos-x86_64",
}

#: Normalize the many spellings of an architecture to the ones used in _SUFFIXES.
_MACHINE_ALIASES: dict[str, str] = {
    "amd64": "x86_64",
    "x86_64": "x86_64",
    "x64": "x86_64",
    "arm64": "arm64",
    "aarch64": "arm64",
}


def normalize_machine(machine: str) -> str:
    """Return the canonical architecture name for ``machine`` (alias-resolved)."""
    return _MACHINE_ALIASES.get(machine.lower(), machine.lower())


def asset_suffix(system: str, machine: str) -> str | None:
    """Return the release asset suffix for an OS/arch, or ``None`` if unsupported.

    Args:
        system: OS name as reported by :func:`platform.system` (e.g. ``"Linux"``).
        machine: Architecture as reported by :func:`platform.machine` (aliases ok).

    Returns:
        ``"linux-x86_64"`` / ``"macos-arm64"`` / ``"macos-x86_64"``, or ``None`` on
        Windows and unsupported architectures (no standalone Unix asset applies).
    """
    return _SUFFIXES.get((system.lower(), normalize_machine(machine)))


def is_windows(system: str | None = None) -> bool:
    """Return whether ``system`` (default: current) is Windows."""
    return (system or platform.system()).lower() == "windows"


def veaf_tools_binary_name(system: str | None = None) -> str:
    """File name of the main binary on ``system``: ``veaf-tools[.exe]``."""
    return "veaf-tools.exe" if is_windows(system) else "veaf-tools"


def updater_binary_name(system: str | None = None) -> str:
    """File name of the updater binary on ``system``: ``veaf-tools-updater[.exe]``."""
    return "veaf-tools-updater.exe" if is_windows(system) else "veaf-tools-updater"


def veaf_tools_asset_name(system: str | None = None, machine: str | None = None) -> str | None:
    """Release asset name for the main binary, or ``None`` if none applies."""
    suffix = asset_suffix(system or platform.system(), machine or platform.machine())
    return f"veaf-tools-{suffix}" if suffix else None


def updater_asset_name(system: str | None = None, machine: str | None = None) -> str | None:
    """Release asset name for the updater binary, or ``None`` if none applies."""
    suffix = asset_suffix(system or platform.system(), machine or platform.machine())
    return f"veaf-tools-updater-{suffix}" if suffix else None
