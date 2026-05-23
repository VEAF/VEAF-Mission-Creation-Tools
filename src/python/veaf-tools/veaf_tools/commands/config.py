import typer
from mission_builder import ConfigMigrator, MigrationResult
from veaf_libs.lua_module_scanner import get_modules
from veaf_libs.paths import resolve_path

from veaf_tools.app import (
    PAUSE_HELP,
    VERBOSE_HELP,
    VERSION,
    app,
    console,
    logger,
    t,
)


@app.command(help=t("cmd.generate_config.help"))
def generate_config(
    output: str = typer.Option(".", help=t("cmd.generate_config.opt.output")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    logger.set_verbose(verbose)
    console.print(f"[bold green]veaf-tools Generate Config v{VERSION}[/bold green]")

    p_output = resolve_path(path=output, create_if_not_exist=True)

    modules = get_modules()
    if not modules:
        logger.error("No VEAF Lua module information available. Run from a full repo checkout.")
        return

    from veaf_libs.lua_config_generator import generate_mission_yaml_template

    content = generate_mission_yaml_template(modules=modules)
    output_file = p_output / "mission.yaml"
    output_file.write_text(content, encoding="utf-8")
    console.print(f"[bold green]Generated:[/bold green] {output_file}")

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))


@app.command(no_args_is_help=True, help=t("cmd.migrate_config.help"))
def migrate_config(
    input_file: str = typer.Argument(..., help=t("cmd.migrate_config.opt.input")),
    output: str | None = typer.Option(
        None,
        help=t("cmd.migrate_config.opt.output_file"),
    ),
    yaml_output: str | None = typer.Option(
        None,
        "--yaml-output",
        help=t("cmd.migrate_config.opt.yaml_output"),
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    logger.set_verbose(verbose)
    console.print(f"[bold green]veaf-tools Migrate Config v{VERSION}[/bold green]")

    p_input = resolve_path(path=input_file, should_exist=True)
    if not p_input.exists():
        logger.error(f"Input file not found: {p_input}", exception_type=FileNotFoundError)
        return

    # Default output path: <stem>_v6.lua in the same directory.
    if output is None:
        p_output = p_input.parent / f"{p_input.stem}_v6{p_input.suffix}"
    else:
        p_output = resolve_path(path=output)

    console.print(f"Input : {p_input}")
    console.print(f"Output: {p_output}")

    content = p_input.read_text(encoding="utf-8")
    migrator = ConfigMigrator()
    result: MigrationResult = migrator.migrate(content)

    # Write the migrated Lua file.
    p_output.write_text(result.new_content, encoding="utf-8")

    # Report changes.
    if result.removed_dofiles:
        console.print(f"\n[yellow]Commented out {len(result.removed_dofiles)} doFile() call(s):[/yellow]")
        for item in result.removed_dofiles:
            console.print(f"  • {item}")

    if result.wrapped_calls:
        console.print(f"\n[yellow]Wrapped {len(result.wrapped_calls)} bare initialize() call(s):[/yellow]")
        for item in result.wrapped_calls:
            console.print(f"  • {item}")

    if result.warnings:
        console.print("\n[bold yellow]Warnings (manual review needed):[/bold yellow]")
        for w in result.warnings:
            console.print(f"  ⚠  {w}")

    if result.enabled_modules:
        console.print(
            f"\n[bold cyan]Modules found ({len(result.enabled_modules)}):[/bold cyan] "
            + ", ".join(result.enabled_modules)
        )
    else:
        console.print("\n[yellow]No VEAF module initialize() calls found.[/yellow]")

    # YAML snippet.
    if yaml_output:
        p_yaml = resolve_path(path=yaml_output)
        p_yaml.write_text(result.yaml_snippet, encoding="utf-8")
        console.print(f"\n[bold cyan]lua_modules YAML snippet written to:[/bold cyan] {p_yaml}")
    else:
        console.print("\n[bold cyan]lua_modules YAML snippet (paste into mission.yaml):[/bold cyan]")
        console.print(result.yaml_snippet)

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
