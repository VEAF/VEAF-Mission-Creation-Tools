"""
Worker modules for VEAF Waypoints Injector Package.

Provides extraction and injection of waypoints from/to DCS missions.
"""

import re
from pathlib import Path
from typing import Any

import luadata
import yaml
from mission_tools import DcsMission, Group, read_miz, write_miz
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from veaf_libs.base_worker import BaseWorker
from veaf_libs.group_injector_worker import GroupInjectorWorker
from veaf_libs.i18n import t, tn
from veaf_libs.logger import logger
from veaf_libs.progress import spinner_context

from .waypoints_manager import WaypointDefinition, WaypointsManager

console = Console()


class WaypointsInjectorWorker(GroupInjectorWorker):
    """
    Worker class that injects waypoints into aircraft groups from a YAML file.
    """

    def __init__(self, waypoints_file: Path | None, input_mission: Path | None, output_mission: Path | None):
        """
        Initialize the worker.

        Args:
            waypoints_file: Path to the YAML file with waypoint definitions
            input_mission: Path to the input .miz mission file
            output_mission: Path to the output .miz mission file
        """
        self.waypoints_file = waypoints_file
        self.groups: dict[str, Group] = {}
        self.waypoints_manager: WaypointsManager | None = None
        super().__init__(config_file=waypoints_file, input_mission=input_mission, output_mission=output_mission)

    def load_config(self) -> WaypointsManager | None:
        """Load waypoint configuration from YAML file."""
        waypoints_manager = WaypointsManager()
        try:
            if self.waypoints_file:
                waypoints_manager.read_yaml(self.waypoints_file)
        except Exception as e:
            logger.error(
                t("waypoints_injector.error.load_config", path=self.waypoints_file, error=str(e)),
                exception_type=RuntimeError,
            )
        self.waypoints_manager = waypoints_manager
        return waypoints_manager

    def add_group(self, group: Group) -> None:
        """Add a group to the list of processing targets."""
        if group.name:
            self.groups[group.name] = group

    def process_group(self, group: Group) -> None:
        """Collect the group for later processing in process_groups()."""
        if group.human_pilot:
            logger.debug(f"Adding group '{group.name}' to waypoint injection targets (human pilot detected)")
        self.add_group(group)

    def read_mission(self, silent: bool = False) -> None:
        """Load the mission and collect all groups."""
        if not silent:
            logger.info(t("group_injector.reading_mission", path=self.input_mission))
        assert self.input_mission is not None
        self.dcs_mission = read_miz(self.input_mission)
        logger.debug("Searching for all aircraft groups")
        for group in self.dcs_mission.iter_groups():
            self.process_group(group)

    def process_groups(self, silent: bool = False) -> None:
        """Process all aircraft groups and inject waypoints."""
        if not silent:
            logger.info(tn("presets_injector.processing_groups", len(self.groups)))

        nb_groups_processed = 0
        nb_groups_without_plan = 0
        if not self.waypoints_manager:
            logger.warning(t("waypoints_injector.no_manager"))
            return
        for group in [g for g in self.groups.values() if g.human_pilot]:
            # Try to find a flight plan for this group
            flight_plan = self.waypoints_manager.get_flight_plan_for(
                coalition=group.coalition,
                category=group.aircraft_type,
                aircraft_type=group.unit_type,
                country=group.country,
            )

            if flight_plan and flight_plan.waypoints:
                logger.debug(f"Injecting {len(flight_plan.waypoints)} waypoint(s) into group '{group.name}'")
                self._inject_waypoints_into_group(group, flight_plan.waypoints)
                nb_groups_processed += 1
            else:
                nb_groups_without_plan += 1
                logger.debugwarn(
                    f"No flight plan found for group '{group.name}' (coalition={group.coalition}, category={group.aircraft_type}, type={group.unit_type}, country={group.country})"
                )

        if not silent:
            logger.detail(tn("waypoints_injector.injected", nb_groups_processed))
            # A bare "0 injected" reads like a failure; say how many human groups had no
            # flight plan assigned in waypoints.yaml so the outcome is unambiguous.
            if nb_groups_without_plan:
                logger.detail(tn("waypoints_injector.no_flight_plan", nb_groups_without_plan))

    def _inject_waypoints_into_group(self, group: Group, waypoints: list[WaypointDefinition]) -> None:
        """Inject waypoints into a group's route, preserving its existing route.

        Each injected waypoint is **appended** to the end of the group's current
        route, *except* when a waypoint with the same ``name`` already exists — in
        which case it replaces that one in place. The group's existing points
        (notably its takeoff-from-parking / landing points) are never wiped, so a
        human-piloted slot keeps a valid departure (otherwise DCS reports
        "your flight is delayed to start" and the slot cannot be taken).
        """
        # Start from the existing route (preserve its metadata and points).
        route: dict[str, Any] = group.group_dcs.get("route") or {"points": [], "routeRelativeTOD": False}
        points: list[dict[str, Any]] = route.get("points") or []
        route["points"] = points

        # Index existing points by (non-empty) name for in-place replacement.
        index_by_name = {p["name"]: i for i, p in enumerate(points) if p.get("name")}

        for waypoint in waypoints:
            wp_dict = waypoint.to_dict()
            name = wp_dict.get("name")
            if name and name in index_by_name:
                points[index_by_name[name]] = wp_dict  # replace the same-named waypoint in place
            else:
                if name:
                    index_by_name[name] = len(points)
                points.append(wp_dict)  # append at the end

        # Renumber sequentially (DCS expects 1-based contiguous `num`).
        for i, point in enumerate(points, 1):
            point["num"] = i

        # DCS refuses to save a flight whose route has no waypoint with a locked
        # ETA ("Route has no waypoints with locked time!"). If none is locked,
        # lock the first waypoint (its departure), as DCS does.
        if points and not any(point.get("ETA_locked") for point in points):
            points[0]["ETA_locked"] = True

        # Inject route back into group.
        group.group_dcs["route"] = route

    def write_mission(self, silent: bool = False) -> None:
        """Write the mission file."""
        if not silent:
            logger.info(t("group_injector.writing_mission"))

        assert self.dcs_mission is not None
        write_miz(mission=self.dcs_mission, miz_file_path=self.output_mission)

    def work(self, silent: bool = False) -> None:
        """Main work function."""
        # Load the mission from the .miz file
        with spinner_context(t("group_injector.spinner.reading", path=self.input_mission), silent=silent):
            self.read_mission(silent)

        # Process all aircraft groups
        with spinner_context(t("waypoints_injector.spinner.processing_groups"), silent=silent):
            self.process_groups(silent)

        # Write the mission file
        with spinner_context(t("group_injector.spinner.writing"), silent=silent):
            self.write_mission(silent)


class WaypointsExtractorWorker(BaseWorker):
    """
    Worker class that extracts waypoints from DCS missions or Lua settings files.
    """

    def __init__(
        self,
        input_mission: Path | None = None,
        output_yaml: Path | None = None,
        group_name_pattern: str = ".*",
        input_lua: Path | None = None,
        aircraft_type: str | None = None,
    ):
        """
        Initialize the extractor.

        Args:
            input_mission: Path to the input .miz mission file
            output_yaml: Path to the output YAML file
            group_name_pattern: Regular expression pattern to match group names
            input_lua: Path to input Lua settings file (alternative to mission)
            aircraft_type: Filter by aircraft type: 'plane', 'helicopter', or None for both
        """
        if (input_mission is None and input_lua is None) or (input_mission is not None and input_lua is not None):
            raise ValueError("Must provide exactly one of: input_mission or input_lua")

        # Validate aircraft_type if provided
        if aircraft_type and aircraft_type not in ("plane", "helicopter"):
            raise ValueError(f"Invalid aircraft_type: {aircraft_type}. Must be 'plane', 'helicopter', or None")

        self.input_mission = input_mission
        self.input_lua = input_lua
        self.output_yaml = output_yaml
        self.group_name_pattern = re.compile(group_name_pattern) if group_name_pattern else None
        self.aircraft_type = aircraft_type  # Filter by aircraft type
        self.dcs_mission: DcsMission | None = None
        self.lua_data: dict | None = None
        self.extracted_waypoints: dict[str, Any] = {"waypoints": {}}
        self.matched_groups: dict[str, dict] = {}

    def read_lua_file(self, silent: bool = False) -> bool:
        """
        Load and parse waypoints from a Lua settings file.

        Returns:
            True if loading succeeded, False otherwise
        """
        if not self.input_lua:
            logger.error(t("waypoints_injector.no_lua_file"), exception_type=ValueError)
            return False

        if not silent:
            logger.info(t("waypoints_injector.reading_lua", path=self.input_lua))

        try:
            content = self.input_lua.read_text(encoding="utf-8")

            # Try to parse the Lua file
            # Note: Some Lua files with comments or complex syntax may not parse correctly
            self.lua_data = luadata.unserialize(content, keep_as_dict=["waypoints", "settings"])  # type: ignore[assignment]

            if not self.lua_data:
                logger.warning(t("waypoints_injector.lua_empty"))
                return False

            if not silent:
                logger.info(t("waypoints_injector.lua_parsed", path=self.input_lua))
                logger.debug(
                    f"Found keys in Lua data: {list(self.lua_data.keys()) if isinstance(self.lua_data, dict) else 'Not a dict'}"
                )

            return True

        except Exception as e:
            logger.error(t("waypoints_injector.lua_read_failed", error=str(e)), exception_type=type(e))
            return False

    def read_mission(self, silent: bool = False) -> None:
        """Load the mission from the .miz file."""
        if not silent:
            logger.info(t("waypoints_injector.reading_mission", path=self.input_mission))

        assert self.input_mission is not None
        self.dcs_mission = read_miz(self.input_mission)

        if not silent:
            logger.info(t("waypoints_injector.mission_loaded"))

    def extract_from_mission(self) -> None:
        """Extract waypoints from all groups in the mission."""
        if not self.dcs_mission:
            logger.error(t("waypoints_injector.mission_not_loaded"), exception_type=ValueError)
            return

        coalitions_dict = (
            self.dcs_mission.mission_content.get("coalition", {}) if self.dcs_mission.mission_content else {}
        )

        for coalition_name, coalition_data in coalitions_dict.items():
            countries_list = coalition_data.get("country", [])

            for country_dict in countries_list:
                country_name = country_dict.get("name")

                for aircraft_type in ["helicopter", "plane"]:
                    # Skip if filtering by aircraft type and this isn't the one we want
                    if self.aircraft_type and aircraft_type != self.aircraft_type:
                        continue

                    aircraft_data = country_dict.get(aircraft_type)
                    if not aircraft_data:
                        continue

                    groups_list = aircraft_data.get("group", [])

                    for group in groups_list:
                        group_name = group.get("name")

                        # A group with no name reached `pattern.match(None)` and raised TypeError,
                        # taking the whole extraction down (SECREV-2 / VMR-067). It cannot match a
                        # name pattern anyway, and it has no usable key, so it is skipped.
                        if not group_name:
                            logger.debug(f"skipping a group with no name in {coalition_name}/{country_name}")
                            continue

                        # Check if group name matches pattern
                        if self.group_name_pattern and not self.group_name_pattern.match(group_name):
                            continue

                        route = group.get("route", {})
                        points = route.get("points", [])

                        if points:
                            key = f"{coalition_name}/{country_name}/{aircraft_type}/{group_name}"
                            self.matched_groups[key] = {
                                "group_name": group_name,
                                "coalition": coalition_name,
                                "country": country_name,
                                "category": aircraft_type,
                                "waypoints_count": len(points),
                                "route": route,
                            }

    def extract_from_lua(self) -> None:
        """Extract waypoints from a Lua settings file."""
        if not self.lua_data:
            logger.error(t("waypoints_injector.no_lua_data"), exception_type=ValueError)
            return

        # Look for waypoints table in the Lua data
        if isinstance(self.lua_data, dict) and "waypoints" in self.lua_data:
            waypoints_data = self.lua_data["waypoints"]

            if isinstance(waypoints_data, dict):
                for wp_name, wp_data in waypoints_data.items():
                    # Check if name matches pattern
                    if self.group_name_pattern and not self.group_name_pattern.match(str(wp_name)):
                        continue

                    self.matched_groups[str(wp_name)] = {"waypoint_name": str(wp_name), "waypoint_data": wp_data}

    def save_extracted_waypoints(self, silent: bool = False) -> None:
        """Save extracted waypoints to YAML file."""
        if not silent:
            logger.info(t("waypoints_injector.saving_waypoints", path=self.output_yaml))

        output_data: dict[str, Any] = {"waypoints": {}}

        # Extract waypoint definitions from matched groups
        for key, group_info in self.matched_groups.items():
            if "waypoint_data" in group_info:
                # From Lua file
                wp_name = group_info["waypoint_name"]
                output_data["waypoints"][wp_name] = group_info["waypoint_data"]
            elif "route" in group_info:
                # From mission file - extract position, altitude, and name from each waypoint
                route = group_info["route"]
                points = route.get("points", [])

                # Create a waypoint set from the group's route with minimal data
                wp_set_name = f"{group_info['group_name']}_waypoints"
                waypoints_list = []

                # Extract only position, altitude, and name from each waypoint
                for point in points:
                    waypoint_dict = {
                        "x": point.get("x", 0),
                        "y": point.get("y", 0),
                        "alt": point.get("alt", 0),
                        "alt_type": point.get("alt_type", "BARO"),
                    }

                    # Add name if it exists
                    if "name" in point:
                        waypoint_dict["name"] = point["name"]

                    waypoints_list.append(waypoint_dict)

                # Store the waypoint set
                output_data["waypoints"][wp_set_name] = (
                    {"waypoints": waypoints_list} if waypoints_list else {"waypoints": []}
                )

        try:
            assert self.output_yaml is not None
            with open(self.output_yaml, "w", encoding="utf-8") as f:
                yaml.dump(output_data, f, default_flow_style=False, allow_unicode=True)

            if not silent:
                logger.info(tn("waypoints_injector.waypoints_saved", len(output_data["waypoints"])))

        except Exception as e:
            logger.error(t("waypoints_injector.save_failed", error=str(e)), exception_type=type(e))

    def display_matched_groups(self) -> None:
        """Display matched groups in a table format."""
        if not self.matched_groups:
            console.print(t("waypoints_injector.no_groups_matched"))
            return

        table = Table(title="Matched Groups")
        table.add_column("Index", style="cyan")
        table.add_column("Group Name", style="green")
        table.add_column("Coalition", style="magenta")
        table.add_column("Country", style="blue")
        table.add_column("Category", style="yellow")
        table.add_column("Waypoints", style="red")

        for idx, (key, info) in enumerate(self.matched_groups.items(), 1):
            if "group_name" in info:
                table.add_row(
                    str(idx),
                    info["group_name"],
                    info.get("coalition", "N/A"),
                    info.get("country", "N/A"),
                    info.get("category", "N/A"),
                    str(info.get("waypoints_count", 0)),
                )
            else:
                table.add_row(str(idx), info["waypoint_name"], "N/A", "N/A", "N/A", "Lua")

        console.print(table)

    def select_groups_interactively(self) -> int:
        """
        Display matched groups interactively and let user select which ones to include.
        Uses the same UI style as the aircraft group extractor.

        Returns:
            Number of groups selected
        """
        if not self.matched_groups:
            logger.warning(t("waypoints_injector.no_groups_to_select"))
            return 0

        # Display header with style
        header_text = Text("🎯 WAYPOINT SELECTION", style="bold bright_cyan")
        header_text.append(" - Select waypoints to extract", style="cyan")
        console.print(Panel(header_text, border_style="cyan", padding=(1, 2)))

        group_list = list(self.matched_groups.keys())
        selected_groups: dict[str, dict] = {}
        skip_all = False

        for idx, group_key in enumerate(group_list, 1):
            if skip_all:
                break

            group_info = self.matched_groups[group_key]

            # Handle both mission-extracted groups and Lua-extracted waypoints
            if "group_name" in group_info:
                # Mission-extracted group
                coalition = group_info.get("coalition", "N/A")
                country = group_info.get("country", "N/A")
                category = group_info.get("category", "N/A")
                group_name = group_info["group_name"]
                waypoints_count = group_info.get("waypoints_count", 0)

                # Display group number and name
                console.print(
                    f"[bold bright_yellow]▶ [{idx}][/bold bright_yellow] [bold bright_green]{group_name}[/bold bright_green]"
                )

                # Coalition with color coding
                coalition_color = "bright_blue" if coalition == "blue" else "bright_red"
                coalition_icon = "🔵" if coalition == "blue" else "🔴"
                console.print(
                    f"  {coalition_icon} [{coalition_color}]{coalition.upper()}[/{coalition_color}] | [white]{country}[/white]"
                )

                # Aircraft type and waypoints
                aircraft_emoji = "✈️ " if category == "plane" else "🚁 "
                console.print(
                    f"  {aircraft_emoji}[bright_cyan]{category}[/bright_cyan] | [bright_yellow]{waypoints_count} waypoint(s)[/bright_yellow]"
                )
            else:
                # Lua-extracted waypoint
                waypoint_name = group_info["waypoint_name"]

                # Display waypoint number and name
                console.print(
                    f"[bold bright_yellow]▶ [{idx}][/bold bright_yellow] [bold bright_green]{waypoint_name}[/bold bright_green]"
                )
                console.print(t("waypoints_injector.source_lua"))

            # Ask user for confirmation using standard input
            console.print(
                t("waypoints_injector.include_prompt"),
                end="",
            )
            response = input().strip().lower()

            if response in ("y", "yes"):
                selected_groups[group_key] = group_info
                console.print("  [bold bright_green]✅ Included[/bold bright_green]\n")
            elif response in ("end",):
                console.print(t("waypoints_injector.skipping_remaining"))
                skip_all = True
            else:
                # Default: skip (n, empty string, or any other input)
                console.print("  [dim bright_black]⊘ Skipped[/dim bright_black]\n")

        # Update matched_groups to only include selected ones
        self.matched_groups = selected_groups

        # Display summary with style
        summary_text = Text(f"📊 Summary: {len(selected_groups)} waypoint(s) selected", style="bold bright_yellow")
        console.print(Panel(summary_text, border_style="yellow", padding=(1, 2)))

        return len(selected_groups)

    def work(self) -> None:
        """Implement BaseWorker: delegates to extract() with default parameters."""
        self.extract()

    def extract(self, interactive: bool = False, silent: bool = False) -> None:
        """
        Main extraction workflow.

        Args:
            interactive: If True, show matched groups and ask for confirmation
            silent: If True, suppress info messages
        """
        # Load data
        if self.input_lua:
            with spinner_context(t("waypoints_injector.spinner.reading_lua", path=self.input_lua), silent=silent):
                self.read_lua_file(silent)
            with spinner_context(t("waypoints_injector.spinner.extracting_lua"), silent=silent):
                self.extract_from_lua()
        else:
            with spinner_context(
                t("waypoints_injector.spinner.reading_mission", path=self.input_mission), silent=silent
            ):
                self.read_mission(silent)
            with spinner_context(t("waypoints_injector.spinner.extracting_mission"), silent=silent):
                self.extract_from_mission()

        # Interactive selection mode
        if interactive:
            console.print()
            num_selected = self.select_groups_interactively()

            if num_selected == 0:
                logger.info(t("waypoints_injector.none_selected"))
                return

        # Save waypoints
        with spinner_context(t("waypoints_injector.spinner.saving"), silent=silent):
            self.save_extracted_waypoints(silent)
