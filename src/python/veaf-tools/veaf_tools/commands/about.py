"""
This program provides a command-line interface (CLI) tool for managing DCS missions.

Features:
- Provides a CLI interface.
- Logs the details of the operation in the 'veaf-tools.log' file.

Usage:
- Run the script with 'veaf-tools.exe' to access the CLI.
- Use the 'about' command to learn about the VEAF and this program.
- Use the 'inject-presets' command to inject radio presets into a mission file.
- Use the 'build-mission' command to build a .miz file from a VEAF mission folder.

Example:
- To inject presets into a mission file:
      'python veaf-tools.py inject-presets --verbose --presets-file my_presets.yaml my_mission.miz my_output.miz'

All the commands feature both `--help` and `--readme` options that display online help.
"""

import typer
from rich.table import Table
from veaf_libs.lua_module_scanner import get_modules

from veaf_tools.app import VERSION, app, console, t


@app.command(help=t("cmd.about.help"))
def about(
    modules: bool = typer.Option(False, "--modules", help=t("cmd.about.opt.modules")),
) -> None:
    if modules:
        mod_list = get_modules()
        if not mod_list:
            console.print(t("cmd.about.no_modules"))
            return
        table = Table(title=f"VEAF Lua Modules ({len(mod_list)} total)")
        table.add_column("ID", style="cyan", no_wrap=True)
        table.add_column("Version", style="green")
        table.add_column("File", style="dim")
        for mod in mod_list:
            table.add_row(mod["id"], mod["version"], mod["filename"])
        console.print(table)
        return

    console.print(t("cmd.about.tool_version", version=VERSION))
    url = "https://www.veaf.org"
    console.print(t("cmd.about.veaf"))
    console.print(t("cmd.about.veaf_desc"))
    console.print(t("cmd.about.website", url=url), style="blue")
    if typer.confirm(t("cmd.about.open_website")):
        typer.launch(url)
