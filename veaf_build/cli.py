"""
VEAF Tools - Build and Release CLI

Compiles VEAF Tools executables and prepares a release.

This script automates the complete build and release process:
1. Validates prerequisites (PyInstaller, Git, etc.)
2. Builds the Lua scripts artifact
3. Compiles Python executables (veaf-tools, veaf-tools-updater)
4. Creates a release package (published.zip)
5. Optionally publishes to GitHub

Usage:
    veaf-build build --version 6.0.2
    veaf-build publish --version 6.0.2
    veaf-build build-and-publish --version 6.0.2
    veaf-build --help
"""

import json
import os
import sys
from hashlib import sha256
from pathlib import Path
from typing import Any

import typer
import yaml
from veaf_libs.dcs_bridge_capture import DEFAULT_SERVE_URL  # type: ignore[import-not-found]
from veaf_libs.logger import console, logger  # type: ignore[import-not-found]
from veaf_libs.progress import spinner_context  # type: ignore[import-not-found]

from veaf_build.github import version_is_prerelease
from veaf_build.worker import PAUSE_MESSAGE, VERBOSE_HELP, BuildAndReleaseWorker

CONFIG_FILE: str = "veaf-tools-config.yaml"

app = typer.Typer(
    help="VEAF Tools Build and Release CLI",
    no_args_is_help=True,
)


def load_config() -> dict[str, Any]:
    """Load configuration from veaf-tools-config.yaml if it exists."""
    config_path = Path.cwd() / CONFIG_FILE

    if not config_path.exists():
        return {}

    try:
        with open(config_path, encoding="utf-8") as f:
            config = yaml.safe_load(f)
            if config is None:
                return {}
            logger.debug(f"Loaded configuration from {config_path}")
            return config
    except Exception as e:
        logger.warning(f"Failed to load configuration file: {e}")
        return {}


def _resolve_version(version: str | None) -> str:
    """Resolve version from argument or package.json."""
    if version:
        return version
    version_file = Path.cwd() / "package.json"
    if version_file.exists():
        with open(version_file) as f:
            if resolved := json.load(f).get("version"):
                return resolved
    logger.error("Version not specified and package.json not found")
    sys.exit(1)


def _resolve_token(token: str | None, config: dict[str, Any]) -> str:
    """Resolve GitHub token from argument, config file, or environment."""
    github_config = config.get("github", {})
    effective_token = token or github_config.get("token") or os.getenv("GITHUB_TOKEN")
    if not effective_token:
        logger.error(
            "GitHub token not provided. Use --token, set GITHUB_TOKEN env var, or add to veaf-tools-config.yaml"
        )
        sys.exit(1)
    return effective_token


# ============================================================================
# Commands
# ============================================================================


@app.command()
def build(
    version: str | None = typer.Option(
        None,
        help="Semantic version for the release (e.g., '6.0.2'). If not specified, reads from package.json",
    ),
    skip_lua: bool = typer.Option(False, help="Skip Lua script build"),
    skip_python: bool = typer.Option(False, help="Skip Python executable build"),
    dev: bool = typer.Option(False, "--dev", help="Build in development mode"),
    output: str = typer.Option(".", help="Output directory for release package"),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help="Pause when finished"),
) -> None:
    """Build VEAF Tools without publishing to GitHub."""
    logger.set_verbose(verbose)
    console.print("[bold green]VEAF Tools Build[/bold green]")
    config = load_config()

    worker = BuildAndReleaseWorker(
        version=version,
        skip_lua=skip_lua,
        skip_python=skip_python,
        development_build=dev,
        output_path=Path(output),
        verbose=verbose,
        config=config,
    )
    worker.run()

    if pause:
        input(PAUSE_MESSAGE)


@app.command(name="build-standalone")
def build_standalone(
    version: str | None = typer.Option(
        None,
        help="Semantic version for the build (e.g., '6.0.2'). If not specified, reads from package.json",
    ),
    output: str = typer.Option(
        ".", help="Output directory used to auto-resolve the version (the binary lands in dist/)"
    ),
    with_updater: bool = typer.Option(
        False, "--with-updater", help="Also build the veaf-tools-updater binary (cross-platform updater)"
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help="Pause when finished"),
) -> None:
    """Build the standalone `veaf-tools` executable(s) for the current platform.

    Produces `dist/veaf-tools` (`veaf-tools.exe` on Windows) with no release package.
    With `--with-updater`, also builds `dist/veaf-tools-updater`. Used by the Linux/macOS
    CI jobs to publish per-OS binaries.
    """
    logger.set_verbose(verbose)
    console.print("[bold green]VEAF Tools Standalone Build[/bold green]")
    config = load_config()

    # No skip_lua flag here: run_standalone never runs the Lua-bundle step, so the
    # flag would be dead/misleading. _scan_lua_modules (the exe's modules JSON) still runs.
    worker = BuildAndReleaseWorker(
        version=version,
        output_path=Path(output),
        verbose=verbose,
        config=config,
    )
    exe_path = worker.run_standalone(with_updater=with_updater)
    console.print(f"[bold green]✓[/bold green] Built standalone executable: {exe_path}")

    if pause:
        input(PAUSE_MESSAGE)


@app.command(name="build-kit")
def build_kit(
    version: str | None = typer.Option(None, help="Version stamped in the kit's zip name."),
    exe: str = typer.Option("dist/veaf-tools.exe", "--exe", help="Built veaf-tools executable to bundle."),
    bridge_zip: str | None = typer.Option(
        None, "--bridge-zip", help="VEAF-dcs-bridge release zip to take dcs-serve.exe (+ the Lua) from."
    ),
    bridge_lua: str | None = typer.Option(
        None,
        "--bridge-lua",
        help="Local dcs-bridge.lua for the bundled missions (default: from the zip, else download).",
    ),
    output: str = typer.Option("dist", "--output", help="Directory the kit zip is written to."),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Assemble the map-capture kit zip handed to helpers collecting DCS map data.

    Bundles the `veaf-tools` executable, the bridge server (from a VEAF-dcs-bridge release
    zip when given), a ready bridge mission per supported theatre, and the procedure. No
    `dcs-serve.yaml` is shipped: the server generates its own key on first launch, so the
    artifact carries no secret.
    """
    logger.set_verbose(verbose)
    from veaf_libs.dcs_bridge_capture import resolve_bridge_lua  # type: ignore[import-not-found]

    from veaf_build import kit as kit_mod

    resolved_version = _resolve_version(version)
    repo_root = Path(__file__).parent.parent
    zip_path = Path(output) / f"veaf-map-capture-kit-{resolved_version}.zip"
    staging = Path(output) / "kit-staging"
    zip_source = Path(bridge_zip) if bridge_zip else None

    # Prefer the Lua shipped in the bridge release (matches dcs-serve.exe), else download it.
    lua_path: Path | None = Path(bridge_lua) if bridge_lua else None
    if lua_path is None and zip_source is not None:
        lua_path = kit_mod.extract_bridge_lua(zip_source, staging.parent / "bridge-lua")
    if lua_path is None:
        lua_path = resolve_bridge_lua(None)

    console.print(f"[cyan]Assembling the map-capture kit {resolved_version}...[/cyan]")
    result = kit_mod.assemble_kit(
        staging,
        zip_path,
        veaf_tools_exe=Path(exe),
        procedure_md=repo_root / "doc" / "developer" / "capture-airbases.md",
        bridge_lua=lua_path,
        bridge_zip=zip_source,
    )
    if zip_source is None:
        console.print("[yellow]⚠ no --bridge-zip: the kit ships without dcs-serve.exe[/yellow]")
    console.print(f"[green]✓ kit written: {result} ({result.stat().st_size / 1e6:.1f} MB)[/green]")


@app.command()
def publish(
    version: str | None = typer.Option(
        None,
        help="Semantic version for the release (e.g., '6.0.2'). If not specified, reads from package.json",
    ),
    token: str | None = typer.Option(
        None,
        help="GitHub Personal Access Token with 'repo' scope (or use GITHUB_TOKEN env var)",
    ),
    force: bool = typer.Option(
        False,
        help="Force publish even if release already exists (overwrites with --clobber)",
    ),
    prerelease: bool = typer.Option(
        False,
        help="Mark as pre-release (e.g. RC). Requires a semver pre-release version "
        "(--version 6.9.21-rc1): the release workflow keys off the '-' suffix to leave "
        "published-latest untouched. Test with: veaf-tools-updater update --tag published-v<version>",
    ),
    ci: bool = typer.Option(
        False,
        "--ci",
        help="Non-interactive CI mode: skip all prompts and use RELEASE_NOTES.md as-is.",
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help="Pause when finished"),
) -> None:
    """
    Publish existing release to GitHub (without recompiling).

    Use this after running 'build' and editing RELEASE_NOTES.md.
    It will publish the already-compiled artifacts to GitHub.

    For pre-release testing without affecting production users, publish a semver
    pre-release version (e.g. --version 6.9.21-rc1 --prerelease). The release workflow
    keys off the '-' suffix, so published-latest is left untouched; test with:
        veaf-tools-updater update --tag published-v<version>
    """
    logger.set_verbose(verbose)
    console.print("[bold green]VEAF Tools Publish[/bold green]")
    config = load_config()

    version = _resolve_version(version)
    effective_token = _resolve_token(token, config)

    # A pre-release must carry a semver pre-release suffix: the release workflow keys off the
    # '-' in the version to decide whether to move published-latest, so --prerelease on a plain
    # version (e.g. 6.9.20) would publish a "pre-release" locally yet still let CI advance
    # published-latest — the exact trap that shipped dev to production once.
    if prerelease and not version_is_prerelease(version):
        logger.error(
            f"--prerelease needs a semver pre-release version (got '{version}'). "
            f"Re-run with e.g. --version {version}-rc1, so the release workflow leaves "
            "published-latest on the current stable."
        )
        sys.exit(1)

    # Verify that published.zip exists
    published_zip = Path("published.zip")
    if not published_zip.exists():
        logger.error(f"Release package not found at {published_zip}. Run 'veaf-build build' first.")
        sys.exit(1)

    if not ci:
        # Prepare release notes (interactive — ask to overwrite if exists)
        console.print("\n[bold cyan]Preparing release notes...[/bold cyan]")
        with spinner_context("Loading release notes handler..."):
            worker = BuildAndReleaseWorker(version=version, verbose=verbose, config=config)

        release_notes_path = worker.prepare_release_notes()

        # Pause for editing release notes
        console.print(
            "\n[bold yellow]⏸️  Pause: Edit RELEASE_NOTES.md and press Enter to continue publishing...[/bold yellow]"
        )
        console.print(f"File location: {release_notes_path.resolve()}")
        input(PAUSE_MESSAGE)

    try:
        # Calculate SHA256
        with spinner_context("Calculating SHA256..."):
            with open(published_zip, "rb") as f:
                package_hash = sha256(f.read()).hexdigest()

        # Publish to GitHub
        with spinner_context("Publishing to GitHub..."):
            publisher_worker = BuildAndReleaseWorker(
                version=version,
                github_token=effective_token,
                verbose=verbose,
                config=config,
                prerelease=prerelease,
            )
            publisher_worker._do_publish_to_github(published_zip, package_hash, force=force, skip_git_tags=ci)

        # Display release information
        from rich.table import Table

        release_url = f"https://github.com/{publisher_worker.github_owner}/{publisher_worker.github_repo}/releases/tag/published-v{version}"
        table = Table(title=f"[bold green]Release v{version} Published[/bold green]")
        table.add_column("Property", style="cyan")
        table.add_column("Value", style="green")
        table.add_row("Version", f"v{version}")
        table.add_row("Package", published_zip.name)
        table.add_row("SHA256", f"{package_hash[:16]}...")
        table.add_row("Size", f"{published_zip.stat().st_size / (1024 * 1024):.1f} MB")
        table.add_row("URL", release_url)
        console.print("")
        console.print(table)
        console.print("")

    except Exception as e:
        logger.error(f"Publishing failed: {e}")
        sys.exit(1)

    if pause:
        input(PAUSE_MESSAGE)


@app.command(name="publish-local")
def publish_local(
    target: str = typer.Argument(..., help="Local VEAF mission folder to deploy the build into."),
    published_zip: str = typer.Option(
        "published.zip", help="Path to the built published.zip (default: ./published.zip)."
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help="Pause when finished"),
) -> None:
    """Deploy a built release into a local mission folder (no GitHub).

    Reproduces the end state of publishing to GitHub then running the updater in the
    mission folder: extracts published.zip into <target>/published/ and moves
    veaf-tools.exe / veaf-tools-updater.exe to <target>/. Run `veaf-build build` first.
    """
    from veaf_build.worker import deploy_published_locally

    logger.set_verbose(verbose)
    console.print("[bold green]VEAF Tools Local Publish[/bold green]")

    zip_path = Path(published_zip)
    if not zip_path.exists():
        logger.error(f"Release package not found at {zip_path}. Run 'veaf-build build' first.")
        sys.exit(1)

    target_path = Path(target)
    target_path.mkdir(parents=True, exist_ok=True)

    moved = deploy_published_locally(zip_path, target_path)
    console.print(f"[green]Deployed {zip_path.name} into {target_path.resolve()}[/green]")
    console.print(f"  published/ refreshed; executables at root: {', '.join(moved) or 'none'}")

    if pause:
        input(PAUSE_MESSAGE)


@app.command(name="build-and-publish")
def build_and_publish(
    version: str | None = typer.Option(
        None,
        help="Semantic version for the release (e.g., '6.0.2'). If not specified, reads from package.json",
    ),
    token: str | None = typer.Option(
        None,
        help="GitHub Personal Access Token with 'repo' scope (or use GITHUB_TOKEN env var)",
    ),
    skip_lua: bool = typer.Option(False, help="Skip Lua script build"),
    skip_python: bool = typer.Option(False, help="Skip Python executable build"),
    dev: bool = typer.Option(False, "--dev", help="Build in development mode"),
    output: str = typer.Option(".", help="Output directory for release package"),
    ci: bool = typer.Option(
        False,
        "--ci",
        help="Non-interactive CI mode: skip all prompts and use RELEASE_NOTES.md as-is.",
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """
    Build VEAF Tools and publish to GitHub (combined workflow).

    Builds everything, then pauses to let you edit RELEASE_NOTES.md
    before publishing to GitHub.
    """
    logger.set_verbose(verbose)
    console.print("[bold green]VEAF Tools Build & Publish[/bold green]")
    config = load_config()

    version = _resolve_version(version)
    effective_token = _resolve_token(token, config)

    try:
        # Step 1: Build
        console.print("\n[bold cyan]Step 1: Building...[/bold cyan]")
        worker = BuildAndReleaseWorker(
            version=version,
            skip_lua=skip_lua,
            skip_python=skip_python,
            development_build=dev,
            output_path=Path(output),
            verbose=verbose,
            config=config,
        )
        worker.run()

        if not ci:
            # Step 2: Prepare release notes (interactive)
            console.print("\n[bold cyan]Step 2: Preparing release notes...[/bold cyan]")
            release_notes_path = worker.prepare_release_notes()

            # Step 3: Pause for editing release notes
            console.print(
                "\n[bold yellow]⏸️  Pause: Edit RELEASE_NOTES.md and press Enter to continue publishing...[/bold yellow]"
            )
            console.print(f"File location: {release_notes_path.resolve()}")
            input(PAUSE_MESSAGE)

        # Step 4: Publish
        step_num = 3 if not ci else 2
        console.print(f"\n[bold cyan]Step {step_num}: Publishing to GitHub...[/bold cyan]")
        published_zip = Path(output) / "published.zip"
        if not published_zip.exists():
            logger.error(f"Release package not found at {published_zip}")
            sys.exit(1)

        with spinner_context("Calculating SHA256..."):
            with open(published_zip, "rb") as f:
                package_hash = sha256(f.read()).hexdigest()

        with spinner_context("Publishing to GitHub..."):
            publish_worker = BuildAndReleaseWorker(
                version=version,
                github_token=effective_token,
                verbose=verbose,
                config=config,
            )
            publish_worker._do_publish_to_github(published_zip, package_hash, force=False, skip_git_tags=ci)

        from rich.table import Table

        release_url = f"https://github.com/{publish_worker.github_owner}/{publish_worker.github_repo}/releases/tag/published-v{version}"
        table = Table(title=f"[bold green]Release v{version} Published[/bold green]")
        table.add_column("Property", style="cyan")
        table.add_column("Value", style="green")
        table.add_row("Version", f"v{version}")
        table.add_row("Package", published_zip.name)
        table.add_row("SHA256", f"{package_hash[:16]}...")
        table.add_row("Size", f"{published_zip.stat().st_size / (1024 * 1024):.1f} MB")
        table.add_row("URL", release_url)
        console.print("")
        console.print(table)
        console.print("")

    except Exception as e:
        logger.error(f"Build and publish failed: {e}")
        sys.exit(1)


@app.command(name="update-dcs-data")
def update_dcs_data(
    countries: bool = typer.Option(False, "--countries", help="Regenerate the DCS country name->id table."),
    units: bool = typer.Option(False, "--units", help="Regenerate the DCS units database (YAML + dcsUnits.lua)."),
    radio: bool = typer.Option(False, "--radio", help="Regenerate the DCS aircraft radio specs."),
    airdromes: bool = typer.Option(
        False, "--airdromes", help="Regenerate the airdrome name->id table from committed runtime dumps."
    ),
    airfield_freqs: bool = typer.Option(
        False, "--airfield-freqs", help="Regenerate the airfield ATC-frequency table (needs --dcs-path)."
    ),
    dcs_path: str | None = typer.Option(None, "--dcs-path", help="Path to a DCS World install (for --airfield-freqs)."),
    inject_bridge: str | None = typer.Option(
        None, "--inject-bridge", help="With --airdromes: embed the dcs-bridge into this .miz (makes a bridge mission)."
    ),
    capture: bool = typer.Option(
        False, "--capture", help="With --airdromes: capture airdromes from the running bridge mission, then merge."
    ),
    serve_url: str = typer.Option(DEFAULT_SERVE_URL, "--serve-url", help="dcs-serve base URL for --capture."),
    api_key: str | None = typer.Option(
        None, "--api-key", envvar="DCS_BRIDGE_API_KEY", help="dcs-serve superuser Bearer token for --capture."
    ),
    bridge_lua: str | None = typer.Option(
        None, "--bridge-lua", help="Local dcs-bridge.lua to embed for --inject-bridge (default: download)."
    ),
    all_data: bool = typer.Option(False, "--all", help="Regenerate every datamine-sourced artifact."),
) -> None:
    """Regenerate the DCS reference data committed in this repository.

    Datamine-sourced artifacts are generated from the Quaggles/dcs-lua-datamine
    dump at the pinned ref (`veaf_build.dcs_data.datamine.DATAMINE_REF`), so the
    output is reproducible and CI fails if a committed artifact drifts. With no
    flag, every pure datamine artifact (countries, units) is regenerated; radio
    (manual overlays) and airdromes / airfield-freqs (install-dependent) are
    excluded from --all and must be requested explicitly.
    """
    from veaf_build.dcs_data import countries as countries_provider
    from veaf_build.dcs_data import units as units_provider
    from veaf_build.dcs_data import units_lua
    from veaf_build.dcs_data.datamine import DATAMINE_REF

    run_all = all_data or not (countries or units or radio or airdromes or airfield_freqs)
    ref_short = DATAMINE_REF[:8]

    if airdromes:
        from pathlib import Path

        from veaf_libs import dcs_bridge_capture as capture_mod  # type: ignore[import-not-found]

        from veaf_build.dcs_data import airdromes as airdromes_provider

        if inject_bridge:
            lua = capture_mod.resolve_bridge_lua(bridge_lua)
            res = capture_mod.inject_bridge(Path(inject_bridge), lua)
            console.print(
                f"[green]✓ dcs-bridge injected into {inject_bridge} (trigger #{res['trigger_index']})[/green]"
            )

        if capture:
            console.print(f"[cyan]Capturing airbases from the running mission via {serve_url}...[/cyan]")
            # Falls back to the api_key in a dcs-serve.yaml / dcs-client.yaml nearby.
            key = capture_mod.resolve_api_key(api_key)
            theatre, airbases = capture_mod.capture_airbases(serve_url, key)
            dump_path = capture_mod.write_airbase_dump(theatre, airbases, airdromes_provider.DUMPS_DIR)
            console.print(f"[green]✓ captured theatre '{theatre}' ({len(airbases)} airbases) → {dump_path}[/green]")

        # Regenerate from the committed dumps, unless the run only injected the bridge.
        if capture or not inject_bridge:
            console.print("[cyan]Generating airdrome table from committed runtime dumps...[/cyan]")
            count = airdromes_provider.generate()
            console.print(f"[green]✓ {count} airfields written across all dumped theatres[/green]")

    if airfield_freqs:
        if not dcs_path:
            console.print("[red]--airfield-freqs requires --dcs-path <DCS World install>[/red]")
            raise typer.Exit(code=1)
        from pathlib import Path

        from veaf_build.dcs_data import airfield_freqs as airfield_freqs_provider

        console.print(f"[cyan]Generating airfield ATC-frequency table from {dcs_path}...[/cyan]")
        count = airfield_freqs_provider.generate(Path(dcs_path))
        console.print(f"[green]✓ {count} airfields written across all installed theatres[/green]")

    if run_all or countries:
        console.print(f"[cyan]Generating DCS country table (datamine@{ref_short})...[/cyan]")
        count = countries_provider.generate()
        console.print(f"[green]✓ {count} countries written[/green]")

    if run_all or units:
        console.print(f"[cyan]Generating DCS units database (datamine@{ref_short})...[/cyan]")
        count = units_provider.generate()
        rendered = units_lua.generate()
        console.print(f"[green]✓ {count} units written (dcsUnits.yaml + dcsUnits.lua: {rendered})[/green]")

    # Radio is regenerated only when explicitly requested (--radio), even under
    # --all: it is a hybrid artifact with manual overlays the generator cannot
    # reproduce, so --all must never silently overwrite it.
    if radio:
        console.print(
            "[yellow]⚠ Regenerating radio specs OVERWRITES manual overlays "
            "(`dcs_rejects_on_load` flags + the bilingual critical-aircraft doc). "
            "Re-apply them after generation.[/yellow]"
        )
        console.print(f"[cyan]Generating DCS radio specs (datamine@{ref_short})...[/cyan]")
        from veaf_build.radio_specs_updater import main as update_radio

        update_radio()
        console.print("[green]✓ radio specs written (re-apply manual overlays now)[/green]")
    elif run_all:
        console.print(
            "[yellow]Skipping radio specs under --all: the radio artifact has manual "
            "overlays. Regenerate it explicitly with --radio, then re-apply the "
            "`dcs_rejects_on_load` flags and the hand-written doc section.[/yellow]"
        )


@app.command()
def about() -> None:
    """Show information about the VEAF Tools build system."""
    url = "https://www.veaf.org"
    console.print(__doc__)
    console.print("[bold green]The VEAF - Virtual European Air Force[/bold green]")
    console.print(
        "The VEAF is a community of virtual pilots dedicated to creating and flying high-quality missions in DCS World."
    )
    console.print(f"Website: {url}", style="blue")
    if typer.confirm("Do you want to open the VEAF website in your browser?"):
        typer.launch(url)


def main() -> None:
    """Main entry point."""
    try:
        app()
    finally:
        logger.stop_status()
