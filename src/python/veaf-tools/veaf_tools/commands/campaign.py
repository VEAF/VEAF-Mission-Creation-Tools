from pathlib import Path

import typer
from veaf_libs.mission_validator import ERROR, ValidationIssue

from veaf_tools.app import PAUSE_HELP, VERBOSE_HELP, VERSION, app, console, logger, t, tn


def _report(issues: list[ValidationIssue]) -> bool:
    """Print the issues, errors last, and return whether any is an error."""
    errors = [i for i in issues if i.level == ERROR]
    for issue in issues:
        if issue.level != ERROR:
            console.print(f"[yellow]⚠[/]  {issue.message}")
    for issue in errors:
        console.print(f"[red]✗[/]  {issue.message}")
    if errors:
        console.print(t("cmd.campaign.errors", count=tn("cmd.validate.errors_frag", len(errors))))
    return bool(errors)


@app.command(help=t("cmd.campaign_init.help"))
def campaign_init(
    campaign_folder: str = typer.Argument(".", help=t("cmd.campaign.opt.folder")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """Create a campaign's initial state from its `campaign.yaml`."""
    from campaign_manager.campaign_worker import CampaignWorker

    logger.set_verbose(verbose)
    console.print(t("cmd.campaign_init.title", version=VERSION))
    worker = CampaignWorker(Path(campaign_folder).resolve())
    failed = _report(worker.init())
    if not failed:
        console.print(t("cmd.campaign_init.done", path=worker.state_file))
    if pause:
        input(t("help.pause_msg"))
    if failed:
        raise typer.Exit(code=1)


@app.command(help=t("cmd.campaign_apply.help"))
def campaign_apply(
    state_file: str = typer.Argument(..., help=t("cmd.campaign_apply.opt.state_file")),
    campaign_folder: str = typer.Argument(".", help=t("cmd.campaign.opt.folder")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """Apply a flown mission's state file to the campaign, then play the turn between missions."""
    from campaign_manager.campaign_worker import CampaignWorker
    from campaign_manager.turn_manager import describe_change

    logger.set_verbose(verbose)
    console.print(t("cmd.campaign_apply.title", version=VERSION))
    issues, report = CampaignWorker(Path(campaign_folder).resolve()).apply(Path(state_file).resolve())
    failed = _report(issues)
    if report is not None:
        console.print(t("cmd.campaign_apply.done", mission=report.mission))
        for change in report.changes:
            console.print(f"  - {describe_change(change)}")
        console.print(t("cmd.campaign_apply.objectives"))
        for objective, met in report.objectives:
            mark = "[green]✓[/]" if met else "[red]✗[/]"
            console.print(f"  {mark} {t(f'campaign.objective.{objective.kind}', zones=', '.join(objective.zones))}")
        console.print(t(f"campaign.outcome.{report.outcome}", left=report.missions_left))
        console.print(t("cmd.campaign_apply.debriefing", path=report.folder))
    if pause:
        input(t("help.pause_msg"))
    if failed:
        raise typer.Exit(code=1)


@app.command(help=t("cmd.campaign_next.help"))
def campaign_next(
    campaign_folder: str = typer.Argument(".", help=t("cmd.campaign.opt.folder")),
    players: str | None = typer.Option(None, help=t("cmd.campaign_next.opt.players")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """Create, or refresh, the next mission's folder from the campaign state."""
    from campaign_manager.campaign_manager import parse_players
    from campaign_manager.campaign_worker import CampaignWorker

    logger.set_verbose(verbose)
    console.print(t("cmd.campaign_next.title", version=VERSION))
    expected: tuple[int, int] | None = None
    if players is not None:
        try:
            expected = parse_players(players)
        except ValueError:
            console.print(f"[red]✗[/]  {t('campaign.issue.bad_players', value=players)}")
            raise typer.Exit(code=1) from None
    issues, report = CampaignWorker(Path(campaign_folder).resolve()).next(players=expected)
    failed = _report(issues)
    if report is not None:
        key = "cmd.campaign_next.created" if report.created else "cmd.campaign_next.refreshed"
        console.print(t(key, mission=report.mission, path=report.folder))
        console.print(t("cmd.campaign_next.airbases", count=len(report.airbases)))
        console.print(t("cmd.campaign_next.waypoints" if report.waypoints else "cmd.campaign_next.waypoints_kept"))
        if report.conditions:
            weather = report.conditions.weather
            console.print(
                t(
                    "cmd.campaign_next.conditions",
                    date=report.conditions.date.isoformat(),
                    time=report.conditions.clock,
                    weather=f"{weather['cloud_type']}, {weather['wind_direction']:03.0f}° / {weather['wind_speed']} m/s",
                )
            )
        if report.deck:
            console.print(t("cmd.campaign_briefing.done", path=report.deck))
        if report.mission_deck:
            console.print(t("cmd.campaign_briefing.mission_done", path=report.mission_deck))
    if pause:
        input(t("help.pause_msg"))
    if failed:
        raise typer.Exit(code=1)


@app.command(help=t("cmd.campaign_briefing.help"))
def campaign_briefing(
    campaign_folder: str = typer.Argument(".", help=t("cmd.campaign.opt.folder")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """Write the coming mission's strategic briefing deck, from the campaign and `briefing.yaml`."""
    from campaign_manager.campaign_worker import CampaignWorker

    logger.set_verbose(verbose)
    console.print(t("cmd.campaign_briefing.title", version=VERSION))
    issues, report = CampaignWorker(Path(campaign_folder).resolve()).briefing()
    failed = _report(issues)
    if report is not None:
        console.print(t("cmd.campaign_briefing.done", path=report.path))
        if report.mission_deck:
            console.print(t("cmd.campaign_briefing.mission_done", path=report.mission_deck))
        if not report.prose:
            console.print(t("cmd.campaign_briefing.no_prose"))
        if report.map.offline:
            console.print(t("cmd.campaign_briefing.offline"))
    if pause:
        input(t("help.pause_msg"))
    if failed:
        raise typer.Exit(code=1)


@app.command(help=t("cmd.campaign_validate.help"))
def campaign_validate(
    campaign_folder: str = typer.Argument(".", help=t("cmd.campaign.opt.folder")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
) -> None:
    """Check a campaign folder: its `campaign.yaml`, and its state against it."""
    from campaign_manager.campaign_worker import CampaignWorker

    logger.set_verbose(verbose)
    console.print(t("cmd.campaign_validate.title", version=VERSION))
    failed = _report(CampaignWorker(Path(campaign_folder).resolve()).validate())
    if not failed:
        console.print(t("cmd.campaign_validate.ok"))
    if pause:
        input(t("help.pause_msg"))
    if failed:
        raise typer.Exit(code=1)
