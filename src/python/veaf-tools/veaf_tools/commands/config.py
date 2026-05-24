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
    console.print(t("cmd.generate_config.title", version=VERSION))

    p_output = resolve_path(path=output, create_if_not_exist=True)

    modules = get_modules()
    if not modules:
        logger.error("No VEAF Lua module information available. Run from a full repo checkout.")
        return

    from veaf_libs.lua_config_generator import generate_mission_yaml_template

    content = generate_mission_yaml_template(modules=modules)
    output_file = p_output / "mission.yaml"
    output_file.write_text(content, encoding="utf-8")
    console.print(t("cmd.generate_config.generated", file=output_file))

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
    console.print(t("cmd.migrate_config.title", version=VERSION))

    p_input = resolve_path(path=input_file, should_exist=True)
    if not p_input.exists():
        logger.error(f"Input file not found: {p_input}", exception_type=FileNotFoundError)
        return

    # Default output path: <stem>_v6.lua in the same directory.
    if output is None:
        p_output = p_input.parent / f"{p_input.stem}_v6{p_input.suffix}"
    else:
        p_output = resolve_path(path=output)

    console.print(t("cmd.migrate_config.input", path=p_input))
    console.print(t("cmd.migrate_config.output", path=p_output))

    content = p_input.read_text(encoding="utf-8")
    migrator = ConfigMigrator()
    result: MigrationResult = migrator.migrate(content)

    # Write the migrated Lua file.
    p_output.write_text(result.new_content, encoding="utf-8")

    # Report changes.
    if result.removed_dofiles:
        console.print(t("cmd.migrate_config.dofiles_count", count=len(result.removed_dofiles)))
        for item in result.removed_dofiles:
            console.print(f"  • {item}")

    if result.wrapped_calls:
        console.print(t("cmd.migrate_config.wrapped_count", count=len(result.wrapped_calls)))
        for item in result.wrapped_calls:
            console.print(f"  • {item}")

    if result.warnings:
        console.print(t("cmd.migrate_config.warnings"))
        for w in result.warnings:
            console.print(f"  ⚠  {w}")

    if result.enabled_modules:
        console.print(
            t(
                "cmd.migrate_config.modules_found",
                count=len(result.enabled_modules),
                modules=", ".join(result.enabled_modules),
            )
        )
    else:
        console.print(t("cmd.migrate_config.no_modules_found"))

    # YAML snippet.
    if yaml_output:
        p_yaml = resolve_path(path=yaml_output)
        p_yaml.write_text(result.yaml_snippet, encoding="utf-8")
        console.print(t("cmd.migrate_config.yaml_written", path=p_yaml))
    else:
        console.print(t("cmd.migrate_config.yaml_inline"))
        console.print(result.yaml_snippet)

    console.print(t("msg.work_done"))
    if pause:
        input(t("help.pause_msg"))
