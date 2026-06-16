"""`_display_coverage_report` returns the overall VEAF coverage % (LUA-COVERAGE).

The `--cov-fail-under` gate compares this returned total against the floor, so
the parsing + aggregation in `_display_coverage_report` is the logic worth
covering. lua/luacov are not required: we feed a synthetic luacov report file.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from veaf_build import lua_tests


def _write_report(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")


def test_returns_none_when_no_report(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lua_tests, "_REPORT_FILE", tmp_path / "absent.out")
    assert lua_tests._display_coverage_report() is None


def test_total_aggregates_only_veaf_modules(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    # 60/100 and 40/50 over VEAF modules → 100 hits / 150 lines = 66.67%.
    # The luaunit line is outside src/scripts/veaf and must be ignored.
    report = tmp_path / "luacov.report.out"
    _write_report(
        report,
        "src/scripts/veaf/veaf.lua        60   40   60.00%\n"
        "src/scripts/veaf/veafGrass.lua   40   10   80.00%\n"
        "test/lua/luaunit.lua            999    1   99.90%\n",
    )
    monkeypatch.setattr(lua_tests, "_REPORT_FILE", report)

    total = lua_tests._display_coverage_report()

    assert total == pytest.approx(100 * 100 / 150)  # 66.67%


def test_returns_none_when_no_veaf_rows(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    report = tmp_path / "luacov.report.out"
    _write_report(report, "test/lua/luaunit.lua   999   1   99.90%\n")
    monkeypatch.setattr(lua_tests, "_REPORT_FILE", report)
    assert lua_tests._display_coverage_report() is None
