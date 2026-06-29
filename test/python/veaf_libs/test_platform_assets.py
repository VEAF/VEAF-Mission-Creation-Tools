"""Platform → binary/asset name mapping (UPDATER-CROSSPLATFORM).

The updater selects the right release asset at runtime from the current OS/arch.
These tests pin the mapping for every shipped platform plus the machine aliases,
and the Windows fallback (no Unix asset; `.exe` binary names).
"""

from __future__ import annotations

import pytest

from veaf_libs import platform_assets as pa


@pytest.mark.parametrize(
    ("system", "machine", "suffix"),
    [
        ("Linux", "x86_64", "linux-x86_64"),
        ("Linux", "amd64", "linux-x86_64"),  # alias
        ("Darwin", "arm64", "macos-arm64"),
        ("Darwin", "aarch64", "macos-arm64"),  # alias
        ("Darwin", "x86_64", "macos-x86_64"),
        ("Windows", "AMD64", None),  # no Unix asset on Windows
        ("Linux", "riscv64", None),  # unsupported arch
    ],
)
def test_asset_suffix(system: str, machine: str, suffix: str | None) -> None:
    assert pa.asset_suffix(system, machine) == suffix


def test_binary_names_windows() -> None:
    assert pa.veaf_tools_binary_name("Windows") == "veaf-tools.exe"
    assert pa.updater_binary_name("Windows") == "veaf-tools-updater.exe"


def test_binary_names_unix() -> None:
    assert pa.veaf_tools_binary_name("Linux") == "veaf-tools"
    assert pa.updater_binary_name("Darwin") == "veaf-tools-updater"


def test_asset_names_unix() -> None:
    assert pa.veaf_tools_asset_name("Linux", "x86_64") == "veaf-tools-linux-x86_64"
    assert pa.updater_asset_name("Darwin", "arm64") == "veaf-tools-updater-macos-arm64"


def test_asset_names_windows_are_none() -> None:
    assert pa.veaf_tools_asset_name("Windows", "AMD64") is None
    assert pa.updater_asset_name("Windows", "AMD64") is None


def test_is_windows() -> None:
    assert pa.is_windows("Windows") is True
    assert pa.is_windows("Linux") is False
