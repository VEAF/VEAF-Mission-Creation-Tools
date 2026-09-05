"""``veaf-tools doctor`` — read out the facts a bug report never carries.

Two renderings of one collection pass: a table for the person running it, and a delimited block
they can paste into an issue or a Discord thread without editing anything. The block is the
contract two later lots consume, so its shape lives in :mod:`veaf_libs.diagnostics`, not here — this
module only decides what reaches the screen.
"""

import typer
from rich.table import Table
from veaf_libs.diagnostics import DEFAULT_ERROR_COUNT, build_report

from veaf_tools.app import app, console, t, tn


@app.command(help=t("cmd.doctor.help"))
def doctor(
    paste: bool = typer.Option(False, "--paste", help=t("cmd.doctor.opt.paste")),
    errors: int = typer.Option(DEFAULT_ERROR_COUNT, "--errors", help=t("cmd.doctor.opt.errors")),
) -> None:
    """Collect the diagnostic facts and show them, readable then pasteable.

    Args:
        paste: True → print only the paste block, so the output can be piped or copied wholesale.
        errors: How many recent error records from the tool's log to include; ``0`` for none.
    """
    report = build_report(error_count=errors)
    block = report.to_block()

    if not paste:
        table = Table(title=t("cmd.doctor.title"))
        table.add_column(t("cmd.doctor.col.field"), style="cyan", no_wrap=True)
        table.add_column(t("cmd.doctor.col.value"), style="green")
        for name, value in report.fields.items():
            table.add_row(name, value)
        console.print(table)

        if report.recent_errors:
            console.print(tn("cmd.doctor.recent_errors", len(report.recent_errors)), style="yellow")
            for record in report.recent_errors:
                console.print(record, markup=False, highlight=False, soft_wrap=True, style="dim")
        else:
            console.print(t("cmd.doctor.no_errors"), style="dim")

        console.print(t("cmd.doctor.paste_hint"), style="bold blue")

    # Fenced so the block survives Discord and GitHub Markdown unaltered; `markup=False` keeps Rich
    # from eating a bracketed fragment out of a traceback, and `soft_wrap` keeps a long path on one
    # line — a wrapped line is a line the parser on the other side cannot read back.
    console.print("```text", markup=False, highlight=False, soft_wrap=True)
    console.print(block, markup=False, highlight=False, soft_wrap=True)
    console.print("```", markup=False, highlight=False, soft_wrap=True)
