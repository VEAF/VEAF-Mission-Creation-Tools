"""The campaign economy simulator's fixtures and report (FIX-CAMPAIGN-ECONOMY-BALANCE 04).

The simulator itself is Lua — `test/lua/campaign_sim.lua` runs the real campaign modules on the DCS mocks —, so
what lives here is what Lua cannot do alone: turn a campaign's `campaign-data.yaml` and the framework's spawn data
into the Lua fixtures it loads, and run its report with the Lua the tests use.

    poetry run campaign-sim fixtures          # rewrite the fixtures from their sources
    poetry run campaign-sim report [hours] [seeds] [--csv path]
    poetry run campaign-sim calibrate [hours] [seeds]
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Any

import typer
import yaml

_REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_REPO / "src" / "python" / "veaf-tools"))

from spawn_data_injector.spawn_data_emitter import load_framework_spawn_data, render_spawn_data_lua  # noqa: E402
from veaf_libs.logger import logger  # noqa: E402
from veaf_libs.lua_literals import lua_data  # noqa: E402

from veaf_build.lua_tests import _find_lua  # noqa: E402

FIXTURES = _REPO / "test" / "lua" / "fixtures"
#: The Oronte campaign's data of 2026-11-20, mission 1 (`dynamic-syria/missions/mission-01/mission/src`).
CAMPAIGN_YAML = FIXTURES / "oronte-campaign-data.yaml"
CAMPAIGN_LUA = FIXTURES / "oronte-campaign-data.lua"
SPAWN_DATA_LUA = FIXTURES / "veaf-spawn-data.lua"
AIRDROMES = _REPO / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "airdrome-positions.yaml"
REPORT_LUA = _REPO / "test" / "lua" / "campaign_sim_report.lua"
#: The theatre the fixture's airbases are on.
THEATRE = "Syria"

app = typer.Typer(help="The campaign economy simulator: fixtures and report.")


def campaign_fixture_lua(campaign_yaml: Path = CAMPAIGN_YAML, theatre: str = THEATRE) -> str:
    """The Lua fixture of a campaign: its data, and where its airbases stand.

    Args:
        campaign_yaml: A campaign's `campaign-data.yaml`.
        theatre: The DCS theatre its airbases are on, as `airdrome-positions.yaml` names it.

    Returns:
        A Lua chunk returning `{ data, airbases = { [name] = { lat, lon } } }`.

    Raises:
        KeyError: When a zone names an airbase the theatre does not have.
    """
    data: dict[str, Any] = yaml.safe_load(campaign_yaml.read_text(encoding="utf-8"))
    positions = yaml.safe_load(AIRDROMES.read_text(encoding="utf-8"))["theatres"][theatre]
    known = {entry["name"]: {"lat": entry["lat"], "lon": entry["lon"]} for entry in positions}
    airbases = {zone["airbase"]: known[zone["airbase"]] for zone in data["zones"] if "airbase" in zone}
    return "return " + lua_data({"data": data, "airbases": airbases}) + "\n"


def spawn_data_fixture_lua() -> str:
    """The framework's spawn data, as the build writes it for a mission: the groups an upgrade or a garrison names.

    Returns:
        The Lua source assigning `veafUnits.UnitsDatabase`, `GroupsDatabase` and `AircraftPayloads`.
    """
    return render_spawn_data_lua(load_framework_spawn_data())


@app.command()
def fixtures() -> None:
    """Rewrite the simulator's Lua fixtures from their sources."""
    CAMPAIGN_LUA.write_text(campaign_fixture_lua(), encoding="utf-8", newline="\n")
    SPAWN_DATA_LUA.write_text(spawn_data_fixture_lua(), encoding="utf-8", newline="\n")
    logger.info(f"written {CAMPAIGN_LUA.name} and {SPAWN_DATA_LUA.name}")


@app.command()
def report(
    hours: int = typer.Argument(9, help="Hours of play for each run: three evenings of three hours."),
    seeds: int = typer.Argument(5, help="Runs for each team and strategy; the report gives their median."),
    csv: Path | None = typer.Option(None, help="Write the hour-by-hour rows to this CSV file."),
) -> None:
    """Play each virtual team with each shop strategy and print the report."""
    arguments = [_find_lua(), str(REPORT_LUA), str(hours), str(seeds)]
    if csv:
        arguments.append(str(csv))
    result = subprocess.run(arguments, cwd=_REPO, check=False)  # noqa: S603 - the tests' own Lua, our own script
    raise typer.Exit(result.returncode)


@app.command()
def calibrate(
    hours: int = typer.Argument(9, help="Hours of play for each run."),
    seeds: int = typer.Argument(5, help="Runs; the report gives their median."),
) -> None:
    """Play the average team with no purchase on the rewards of before the lot and of today: the credits an evening."""
    result = subprocess.run(  # noqa: S603 - the tests' own Lua, our own script
        [_find_lua(), str(REPORT_LUA), "calibrate", str(hours), str(seeds)], cwd=_REPO, check=False
    )
    raise typer.Exit(result.returncode)


def main() -> None:
    """Entry point of `poetry run campaign-sim`."""
    app()


if __name__ == "__main__":
    main()
