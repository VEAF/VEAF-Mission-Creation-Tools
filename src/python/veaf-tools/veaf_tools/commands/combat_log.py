"""`combat-log` — the recap per pilot of a mission's combat log (FEAT-COMBAT-LOG).

The mission writes `veaf-combat-log-<date>-<time>.jsonl` in the server's write folder when its
`modules.COMBATLOG` is on; this reads it and prints, pilot by pilot, the weapons fired, the gun rounds,
the hits and the kills, for the debrief.
"""

import json
from pathlib import Path

import typer
from rich.markup import escape
from rich.table import Table
from veaf_libs.combat_log import clock, pilot_recaps, read_combat_log

from veaf_tools.app import app, console, t


def _counted(counter: dict[str, int]) -> str:
    counted = sorted(counter.items(), key=lambda item: -item[1])
    return ", ".join(f"{n} × {escape(weapon)}" for weapon, n in counted) or "—"


@app.command(name="combat-log", no_args_is_help=True, help=t("cmd.combat_log.help"))
def combat_log(
    log_file: Path = typer.Argument(..., exists=True, dir_okay=False, help=t("cmd.combat_log.opt.file")),
    include_ai: bool = typer.Option(False, "--ai", help=t("cmd.combat_log.opt.ai")),
    as_json: bool = typer.Option(False, "--json", help=t("cmd.combat_log.opt.json")),
) -> None:
    log = read_combat_log(log_file)
    recaps = pilot_recaps(log, include_ai)
    if as_json:
        console.print_json(json.dumps([recap.as_dict() for recap in recaps], ensure_ascii=False))
        return
    if log.skipped:
        console.print(t("cmd.combat_log.skipped", count=log.skipped), style="yellow")
    if not recaps:
        console.print(t("cmd.combat_log.empty"))
        return
    table = Table(title=t("cmd.combat_log.title", file=log_file.name))
    for column in ("pilot", "fired", "rounds", "hits", "kills"):
        table.add_column(t(f"cmd.combat_log.col.{column}"))
    for recap in recaps:
        kills = [
            f"{clock(log, kill.time)} {escape(kill.target)} ({escape(kill.weapon)})" + (" ⚠" if kill.friendly else "")
            for kill in recap.kills
        ]
        table.add_row(
            # player names are typed by players: never read as Rich markup
            f"{escape(recap.pilot)}\n{escape(recap.aircraft)}",
            _counted(recap.shots),
            _counted(recap.rounds) + (f"\n{recap.bursts} ×" if recap.bursts else ""),
            _counted(recap.hits),
            "\n".join(kills) or "—",
        )
    console.print(table)
