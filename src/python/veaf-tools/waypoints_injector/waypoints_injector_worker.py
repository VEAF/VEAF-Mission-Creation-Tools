"""
Worker modules for VEAF Waypoints Injector Package.

Provides extraction and injection of waypoints from/to DCS missions.
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional, List, Tuple
import re
import yaml
import copy
import io
import luadata
import typer

from mission_tools import DcsMission, read_miz, write_miz
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text

from veaf_libs.logger import logger
from veaf_libs.progress import spinner_context, progress_context

from .waypoints_manager import WaypointsManager, WaypointDefinition, FlightPlanDefinition

console = Console()


@dataclass
class Group:
    """Class for keeping track of DCS group."""
    group_dcs: Dict
    aircraft_type: str
    country: str
    coalition: str
    category: str
    human_pilot: bool = False
    name: Optional[str] = None
    unit_type: Optional[str] = None


class WaypointsInjectorWorker:
    """
    Worker class that injects waypoints into aircraft groups from a YAML file.
    """
    
    def __init__(self, waypoints_file: Optional[Path], input_mission: Optional[Path], output_mission: Optional[Path]):
        """
        Initialize the worker.
        
        Args:
            waypoints_file: Path to the YAML file with waypoint definitions
            input_mission: Path to the input .miz mission file
            output_mission: Path to the output .miz mission file
        """
        self.waypoints_file = waypoints_file
        self.input_mission = input_mission
        self.output_mission = output_mission
        self.groups: Dict[str, Group] = {}
        self.waypoints_manager: WaypointsManager = self.load_config()
        self.dcs_mission: DcsMission = None

    def load_config(self) -> WaypointsManager:
        """Load waypoint configuration from YAML file."""
        waypoints_manager = WaypointsManager()
        try:
            waypoints_manager.read_yaml(self.waypoints_file)        
            return waypoints_manager
        except Exception as e:
            logger.error(f"Failed to load waypoints file {self.waypoints_file}: {str(e)}", exception_type=RuntimeError)

    def add_group(self, group_dict: Dict, aircraft_type: str, country: str, coalition: str, category: str) -> None:
        """Add a group to the list of processing targets."""
        group = Group(
            group_dcs=group_dict,
            aircraft_type=aircraft_type,
            country=country,
            coalition=coalition,
            category=category
        )
        if name := group_dict.get("name"):
            group.name = name
            if units_list := group_dict.get("units"):
                for unit in units_list:
                    if unit_type := unit.get("type", ""):
                        group.unit_type = unit_type
                    unit_skill = unit.get("skill", "")
                    if unit_skill in ["Client", "Player"]:
                        group.human_pilot = True
                        logger.debug(f"Adding group '{group.name}' to waypoint injection targets (human pilot detected)")
                        break

            self.groups[name] = group

    def read_mission(self, silent: bool = False) -> None:
        """Load the mission from the .miz file and process aircraft groups."""
        if not silent:
            logger.info(f"Reading mission file {self.input_mission}")
        self.dcs_mission = read_miz(self.input_mission)

        logger.debug("Searching for all aircraft groups")
        
        coalitions_dict = self.dcs_mission.mission_content.get("coalition")
        if not coalitions_dict:
            logger.error("Cannot find key 'coalition'", True)
            return
            
        for coalition_name in coalitions_dict.keys():
            self._process_coalition(coalition_name, coalitions_dict[coalition_name])

    def _process_coalition(self, coalition_name: str, coalition_data: Dict) -> None:
        """Process all countries in a coalition."""
        logger.debug(f"Browsing countries in coalition {coalition_name}")
        
        countries_list = coalition_data.get("country")
        if not countries_list:
            logger.debugwarn(f"No key 'country' in /coalition/{coalition_name}")
            return
            
        for country_dict in countries_list:
            self._process_country(country_dict, coalition_name)

    def _process_country(self, country_dict: Dict, coalition_name: str) -> None:
        """Process a country's aircraft groups."""
        country_name = country_dict.get("name")
        if not country_name:
            logger.error(f"Cannot find key 'name' in /coalition/{coalition_name}/country", True)
            return
            
        logger.debug(f"Browsing country {country_name}")
        
        # Process both helicopter and plane groups
        for aircraft_type in ["helicopter", "plane"]:
            self._process_aircraft_type(country_dict, aircraft_type, country_name, coalition_name)

    def _process_aircraft_type(self, country_dict: Dict, aircraft_type: str, country_name: str, coalition_name: str) -> None:
        """Process groups for a specific aircraft type (helicopter or plane)."""
        aircraft_data = country_dict.get(aircraft_type)
        if not aircraft_data:
            logger.debugwarn(f"No key '{aircraft_type}' in /coalition/{coalition_name}/country/{country_name}")
            return
            
        groups_list = aircraft_data.get("group")
        if not groups_list:
            logger.warning(f"Cannot find key 'group' in /coalition/{coalition_name}/country/{country_name}/{aircraft_type}")
            return
            
        for group in groups_list:
            self.add_group(group, aircraft_type=aircraft_type, country=country_name, coalition=coalition_name, category=aircraft_type)

    def process_groups(self, silent: bool = False) -> None:
        """Process all aircraft groups and inject waypoints."""
        if not silent:
            logger.info(f"Processing {len(self.groups)} aircraft group{'s' if len(self.groups) > 1 else ''}")

        nb_groups_processed = 0
        for group in [g for g in self.groups.values() if g.human_pilot]:
            # Try to find a flight plan for this group
            flight_plan = self.waypoints_manager.get_flight_plan_for(
                coalition=group.coalition,
                category=group.category,
                aircraft_type=group.unit_type,
                country=group.country
            )
            
            if flight_plan and flight_plan.waypoints:
                logger.debug(f"Injecting {len(flight_plan.waypoints)} waypoint(s) into group '{group.name}'")
                self._inject_waypoints_into_group(group, flight_plan.waypoints)
                nb_groups_processed += 1
            else:
                logger.debugwarn(f"No flight plan found for group '{group.name}' (coalition={group.coalition}, category={group.category}, type={group.unit_type}, country={group.country})")
        
        if not silent:
            logger.info(f"Injected waypoints into {nb_groups_processed} aircraft group{'s' if nb_groups_processed > 1 else ''}")

    def _inject_waypoints_into_group(self, group: Group, waypoints: List[WaypointDefinition]) -> None:
        """Inject waypoints into a specific group."""
        # Create route structure
        route = {
            'points': [],
            'routeRelativeTOD': False
        }
        
        # Convert waypoint definitions to DCS mission format
        for i, waypoint in enumerate(waypoints, 1):
            wp_dict = waypoint.to_dict()
            # Add sequence number
            wp_dict['num'] = i
            route['points'].append(wp_dict)
        
        # Inject route into group
        group.group_dcs['route'] = route

    def write_mission(self, silent: bool = False) -> None:
        """Write the mission file."""
        if not silent:
            logger.info("Writing mission file")

        write_miz(mission=self.dcs_mission, miz_file_path=self.output_mission)

    def work(self, silent: bool = False) -> None:
        """Main work function."""
        # Load the mission from the .miz file
        with spinner_context(f"Reading {self.input_mission}...", silent=silent):
            self.read_mission(silent)
       
        # Process all aircraft groups
        with spinner_context("Processing groups and injecting waypoints...", silent=silent):
            self.process_groups(silent)

        # Write the mission file
        with spinner_context("Writing mission...", silent=silent):
            self.write_mission(silent)


class WaypointsExtractorWorker:
    """
    Worker class that extracts waypoints from DCS missions or Lua settings files.
    """
    
    def __init__(
        self,
        input_mission: Optional[Path] = None,
        output_yaml: Optional[Path] = None,
        group_name_pattern: str = ".*",
        input_lua: Optional[Path] = None,
        aircraft_type: Optional[str] = None
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
        if aircraft_type and aircraft_type not in ('plane', 'helicopter'):
            raise ValueError(f"Invalid aircraft_type: {aircraft_type}. Must be 'plane', 'helicopter', or None")
        
        self.input_mission = input_mission
        self.input_lua = input_lua
        self.output_yaml = output_yaml
        self.group_name_pattern = re.compile(group_name_pattern) if group_name_pattern else None
        self.aircraft_type = aircraft_type  # Filter by aircraft type
        self.dcs_mission: Optional[DcsMission] = None
        self.lua_data: Optional[Dict] = None
        self.extracted_waypoints: Dict[str, Any] = {'waypoints': {}}
        self.matched_groups: Dict[str, Dict] = {}

    def read_lua_file(self, silent: bool = False) -> bool:
        """
        Load and parse waypoints from a Lua settings file.
        
        Returns:
            True if loading succeeded, False otherwise
        """
        if not self.input_lua:
            logger.error("No Lua file specified", exception_type=ValueError)
            return False
        
        if not silent:
            logger.info(f"Reading Lua file {self.input_lua}")
        
        try:
            content = self.input_lua.read_text(encoding='utf-8')
            
            # Try to parse the Lua file
            # Note: Some Lua files with comments or complex syntax may not parse correctly
            self.lua_data = luadata.unserialize(content, keep_as_dict=['waypoints', 'settings'])
            
            if not self.lua_data:
                logger.warning("Parsed Lua file is empty", exception_type=ValueError)
                return False
            
            if not silent:
                logger.info(f"Successfully parsed Lua file {self.input_lua}")
                logger.debug(f"Found keys in Lua data: {list(self.lua_data.keys()) if isinstance(self.lua_data, dict) else 'Not a dict'}")
            
            return True
        
        except Exception as e:
            logger.error(f"Failed to read Lua file: {str(e)}", exception_type=type(e))
            return False

    def read_mission(self, silent: bool = False) -> None:
        """Load the mission from the .miz file."""
        if not silent:
            logger.info(f"Reading mission file {self.input_mission}")
        
        self.dcs_mission = read_miz(self.input_mission)
        
        if not silent:
            logger.info("Mission file loaded successfully")

    def extract_from_mission(self) -> None:
        """Extract waypoints from all groups in the mission."""
        if not self.dcs_mission:
            logger.error("Mission not loaded", exception_type=ValueError)
            return
        
        coalitions_dict = self.dcs_mission.mission_content.get("coalition", {})
        
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
                        
                        # Check if group name matches pattern
                        if self.group_name_pattern and not self.group_name_pattern.match(group_name):
                            continue
                        
                        route = group.get("route", {})
                        points = route.get("points", [])
                        
                        if points:
                            key = f"{coalition_name}/{country_name}/{aircraft_type}/{group_name}"
                            self.matched_groups[key] = {
                                'group_name': group_name,
                                'coalition': coalition_name,
                                'country': country_name,
                                'category': aircraft_type,
                                'waypoints_count': len(points),
                                'route': route
                            }

    def extract_from_lua(self) -> None:
        """Extract waypoints from a Lua settings file."""
        if not self.lua_data:
            logger.error("Lua data not loaded", exception_type=ValueError)
            return
        
        # Look for waypoints table in the Lua data
        if isinstance(self.lua_data, dict) and 'waypoints' in self.lua_data:
            waypoints_data = self.lua_data['waypoints']
            
            if isinstance(waypoints_data, dict):
                for wp_name, wp_data in waypoints_data.items():
                    # Check if name matches pattern
                    if self.group_name_pattern and not self.group_name_pattern.match(str(wp_name)):
                        continue
                    
                    self.matched_groups[str(wp_name)] = {
                        'waypoint_name': str(wp_name),
                        'waypoint_data': wp_data
                    }

    def save_extracted_waypoints(self, silent: bool = False) -> None:
        """Save extracted waypoints to YAML file."""
        if not silent:
            logger.info(f"Saving extracted waypoints to {self.output_yaml}")
        
        output_data = {'waypoints': {}}
        
        # Extract waypoint definitions from matched groups
        for key, group_info in self.matched_groups.items():
            if 'waypoint_data' in group_info:
                # From Lua file
                wp_name = group_info['waypoint_name']
                output_data['waypoints'][wp_name] = group_info['waypoint_data']
            elif 'route' in group_info:
                # From mission file - extract position, altitude, and name from each waypoint
                route = group_info['route']
                points = route.get('points', [])
                
                # Create a waypoint set from the group's route with minimal data
                wp_set_name = f"{group_info['group_name']}_waypoints"
                waypoints_list = []
                
                # Extract only position, altitude, and name from each waypoint
                for point in points:
                    waypoint_dict = {
                        'x': point.get('x', 0),
                        'y': point.get('y', 0),
                        'alt': point.get('alt', 0),
                        'alt_type': point.get('alt_type', 'BARO'),
                    }
                    
                    # Add name if it exists
                    if 'name' in point:
                        waypoint_dict['name'] = point['name']
                    
                    waypoints_list.append(waypoint_dict)
                
                # Store the waypoint set
                output_data['waypoints'][wp_set_name] = {
                    'waypoints': waypoints_list
                } if waypoints_list else {'waypoints': []}
        
        try:
            with open(self.output_yaml, 'w', encoding='utf-8') as f:
                yaml.dump(output_data, f, default_flow_style=False, allow_unicode=True)
            
            if not silent:
                logger.info(f"Successfully saved {len(output_data['waypoints'])} waypoint set(s)")
        
        except Exception as e:
            logger.error(f"Failed to save YAML file: {str(e)}", exception_type=type(e))

    def display_matched_groups(self) -> None:
        """Display matched groups in a table format."""
        if not self.matched_groups:
            console.print("[yellow]No groups matched the pattern[/yellow]")
            return
        
        table = Table(title="Matched Groups")
        table.add_column("Index", style="cyan")
        table.add_column("Group Name", style="green")
        table.add_column("Coalition", style="magenta")
        table.add_column("Country", style="blue")
        table.add_column("Category", style="yellow")
        table.add_column("Waypoints", style="red")
        
        for idx, (key, info) in enumerate(self.matched_groups.items(), 1):
            if 'group_name' in info:
                table.add_row(
                    str(idx),
                    info['group_name'],
                    info.get('coalition', 'N/A'),
                    info.get('country', 'N/A'),
                    info.get('category', 'N/A'),
                    str(info.get('waypoints_count', 0))
                )
            else:
                table.add_row(
                    str(idx),
                    info['waypoint_name'],
                    'N/A',
                    'N/A',
                    'N/A',
                    'Lua'
                )
        
        console.print(table)

    def select_groups_interactively(self) -> int:
        """
        Display matched groups interactively and let user select which ones to include.
        Uses the same UI style as the aircraft group extractor.
        
        Returns:
            Number of groups selected
        """
        if not self.matched_groups:
            logger.warning("No groups found to select from")
            return 0
        
        # Display header with style
        header_text = Text("🎯 WAYPOINT SELECTION", style="bold bright_cyan")
        header_text.append(" - Select waypoints to extract", style="cyan")
        console.print(Panel(header_text, border_style="cyan", padding=(1, 2)))
        
        group_list = list(self.matched_groups.keys())
        selected_groups: Dict[str, Dict] = {}
        skip_all = False
        
        for idx, group_key in enumerate(group_list, 1):
            if skip_all:
                break
                
            group_info = self.matched_groups[group_key]
            
            # Handle both mission-extracted groups and Lua-extracted waypoints
            if 'group_name' in group_info:
                # Mission-extracted group
                coalition = group_info.get('coalition', 'N/A')
                country = group_info.get('country', 'N/A')
                category = group_info.get('category', 'N/A')
                group_name = group_info['group_name']
                waypoints_count = group_info.get('waypoints_count', 0)
                
                # Display group number and name
                console.print(f"[bold bright_yellow]▶ [{idx}][/bold bright_yellow] [bold bright_green]{group_name}[/bold bright_green]")
                
                # Coalition with color coding
                coalition_color = "bright_blue" if coalition == "blue" else "bright_red"
                coalition_icon = "🔵" if coalition == "blue" else "🔴"
                console.print(f"  {coalition_icon} [{coalition_color}]{coalition.upper()}[/{coalition_color}] | [white]{country}[/white]")
                
                # Aircraft type and waypoints
                aircraft_emoji = "✈️ " if category == "plane" else "🚁 "
                console.print(f"  {aircraft_emoji}[bright_cyan]{category}[/bright_cyan] | [bright_yellow]{waypoints_count} waypoint(s)[/bright_yellow]")
            else:
                # Lua-extracted waypoint
                waypoint_name = group_info['waypoint_name']
                
                # Display waypoint number and name
                console.print(f"[bold bright_yellow]▶ [{idx}][/bold bright_yellow] [bold bright_green]{waypoint_name}[/bold bright_green]")
                console.print("  [bright_magenta]📋 Source:[/bright_magenta] [white]Lua settings file[/white]")
            
            # Ask user for confirmation using standard input
            console.print("  [bold bright_cyan]❓ Include this waypoint?[/bold bright_cyan] (y/n/end) [[bright_yellow]n[/bright_yellow]]: ", end="")
            response = input().strip().lower()
            
            if response in ("y", "yes"):
                selected_groups[group_key] = group_info
                console.print("  [bold bright_green]✅ Included[/bold bright_green]\n")
            elif response in ("end",):
                console.print("  [dim bright_black]⊘ Skipping all remaining[/dim bright_black]\n")
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

    def extract(self, interactive: bool = False, silent: bool = False) -> None:
        """
        Main extraction workflow.
        
        Args:
            interactive: If True, show matched groups and ask for confirmation
            silent: If True, suppress info messages
        """
        # Load data
        if self.input_lua:
            with spinner_context(f"Reading {self.input_lua}...", silent=silent):
                self.read_lua_file(silent)
            with spinner_context("Extracting waypoints from Lua...", silent=silent):
                self.extract_from_lua()
        else:
            with spinner_context(f"Reading {self.input_mission}...", silent=silent):
                self.read_mission(silent)
            with spinner_context("Extracting waypoints from mission...", silent=silent):
                self.extract_from_mission()
        
        # Interactive selection mode
        if interactive:
            console.print()
            num_selected = self.select_groups_interactively()
            
            if num_selected == 0:
                logger.info("No waypoints selected for extraction")
                return
        
        # Save waypoints
        with spinner_context("Saving waypoints to YAML...", silent=silent):
            self.save_extracted_waypoints(silent)
