"""
Worker module for the VEAF Aircraft Groups Injector.
Combines validation and injection of aircraft groups from YAML files into DCS missions.
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
import re
import yaml
import copy

from mission_tools import DcsMission, read_miz, write_miz
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

from veaf_libs.logger import logger
from veaf_libs.progress import spinner_context, progress_context

console = Console()


# ============================================================================
# Validation Classes
# ============================================================================

class ValidationError:
    """Represents a single validation error."""
    
    def __init__(self, level: str, path: str, message: str, details: Optional[str] = None):
        """
        Initialize a validation error.
        
        Args:
            level: 'error', 'warning', or 'info'
            path: Path in the YAML structure (e.g., "airplanes/blue/France/group1/units[0]")
            message: Brief description of the problem
            details: Optional detailed explanation
        """
        self.level = level
        self.path = path
        self.message = message
        self.details = details
    
    def __str__(self) -> str:
        """Format error for display."""
        result = f"[{self.level.upper()}] {self.path}: {self.message}"
        if self.details:
            result += f"\n  → {self.details}"
        return result


# ============================================================================
# Injection Classes
# ============================================================================

@dataclass
class InjectionResult:
    """Result of an injection operation."""
    success: bool
    groups_injected: int
    message: str
    details: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.details is None:
            self.details = {}


# ============================================================================
# Main Worker Classes
# ============================================================================

class AircraftGroupsYAMLValidator:
    """
    Validator for aircraft groups YAML files.
    Validates structure, required fields, and data types.
    """
    
    def __init__(self, yaml_file: Path):
        """
        Initialize the validator.
        
        Args:
            yaml_file: Path to the YAML file to validate
        """
        self.yaml_file = yaml_file
        self.data: Optional[Dict] = None
        self.errors: List[ValidationError] = []
        self.required_aircraft_fields = {'name', 'type', 'units'}
        self.required_unit_fields = {'type'}  # Minimal requirement
    
    def load_yaml(self) -> bool:
        """
        Load and parse the YAML file.
        
        Returns:
            True if loading succeeded, False otherwise
        """
        try:
            with open(self.yaml_file, 'r', encoding='utf-8') as f:
                self.data = yaml.safe_load(f)
            
            if self.data is None:
                self.errors.append(ValidationError(
                    'warning',
                    'root',
                    'YAML file is empty',
                    'The file was parsed successfully but contains no data'
                ))
                return True
            
            return True
        except FileNotFoundError:
            self.errors.append(ValidationError(
                'error',
                'root',
                f'File not found: {self.yaml_file}'
            ))
            return False
        except yaml.YAMLError as e:
            self.errors.append(ValidationError(
                'error',
                'root',
                'YAML parsing error',
                f'Could not parse YAML file: {str(e)}'
            ))
            return False
        except Exception as e:
            self.errors.append(ValidationError(
                'error',
                'root',
                'Unexpected error while loading YAML',
                str(e)
            ))
            return False
    
    def validate_structure(self) -> None:
        """Validate the overall structure of the YAML file."""
        if not self.data:
            return
        
        # Check top-level keys
        valid_categories = {'airplanes', 'helicopters'}
        for category in self.data.keys():
            if category not in valid_categories:
                self.errors.append(ValidationError(
                    'warning',
                    f'root.{category}',
                    f'Unknown aircraft category "{category}"',
                    f'Expected one of: {", ".join(valid_categories)}'
                ))
        
        # Validate each category
        for category in valid_categories:
            if category in self.data:
                self._validate_category(category, self.data[category])
    
    def _validate_category(self, category: str, category_data: Any) -> None:
        """Validate a category (airplanes or helicopters)."""
        if not isinstance(category_data, dict):
            self.errors.append(ValidationError(
                'error',
                f'{category}',
                f'Category must be a dictionary, got {type(category_data).__name__}'
            ))
            return
        
        # Check for 'coalitions' key
        if 'coalitions' not in category_data:
            self.errors.append(ValidationError(
                'warning',
                f'{category}',
                'Missing "coalitions" key',
                'Expected structure: {category: {coalitions: {...}}}'
            ))
            return
        
        coalitions = category_data['coalitions']
        if not isinstance(coalitions, dict):
            self.errors.append(ValidationError(
                'error',
                f'{category}.coalitions',
                f'Coalitions must be a dictionary, got {type(coalitions).__name__}'
            ))
            return
        
        # Validate each coalition
        valid_coalitions = {'blue', 'red'}
        for coalition_name, coalition_data in coalitions.items():
            if coalition_name not in valid_coalitions:
                self.errors.append(ValidationError(
                    'warning',
                    f'{category}.coalitions.{coalition_name}',
                    f'Unknown coalition "{coalition_name}"',
                    f'Expected one of: {", ".join(valid_coalitions)}'
                ))
            
            self._validate_coalition(category, coalition_name, coalition_data)
    
    def _validate_coalition(self, category: str, coalition_name: str, coalition_data: Any) -> None:
        """Validate a coalition within a category."""
        if not isinstance(coalition_data, dict):
            self.errors.append(ValidationError(
                'error',
                f'{category}.coalitions.{coalition_name}',
                f'Coalition data must be a dictionary, got {type(coalition_data).__name__}'
            ))
            return
        
        # Validate each country
        for country_name, country_data in coalition_data.items():
            self._validate_country(category, coalition_name, country_name, country_data)
    
    def _validate_country(self, category: str, coalition_name: str, country_name: str, country_data: Any) -> None:
        """Validate a country within a coalition."""
        path = f'{category}.coalitions.{coalition_name}.{country_name}'
        
        if not isinstance(country_data, dict):
            self.errors.append(ValidationError(
                'error',
                path,
                f'Country data must be a dictionary, got {type(country_data).__name__}'
            ))
            return
        
        # Validate each group
        for group_name, group_data in country_data.items():
            self._validate_group(category, coalition_name, country_name, group_name, group_data)
    
    def _validate_group(self, category: str, coalition_name: str, country_name: str, group_name: str, group_data: Any) -> None:
        """Validate a single aircraft group."""
        path = f'{category}.coalitions.{coalition_name}.{country_name}.{group_name}'
        
        if not isinstance(group_data, dict):
            self.errors.append(ValidationError(
                'error',
                path,
                f'Group data must be a dictionary, got {type(group_data).__name__}'
            ))
            return
        
        # Check required fields
        for field in self.required_aircraft_fields:
            if field not in group_data:
                self.errors.append(ValidationError(
                    'error',
                    path,
                    f'Missing required field "{field}"'
                ))
        
        # Validate group name
        if 'name' in group_data:
            if not isinstance(group_data['name'], str):
                self.errors.append(ValidationError(
                    'error',
                    f'{path}.name',
                    f'Group name must be a string, got {type(group_data["name"]).__name__}'
                ))
        
        # Validate type
        if 'type' in group_data:
            if not isinstance(group_data['type'], str):
                self.errors.append(ValidationError(
                    'error',
                    f'{path}.type',
                    f'Type must be a string, got {type(group_data["type"]).__name__}'
                ))
        
        # Validate units
        if 'units' in group_data:
            self._validate_units(path, group_data['units'])
        
        # Check for extra fields that might indicate structural issues
        self._check_group_structure(path, group_data)
    
    def _validate_units(self, path: str, units: Any) -> None:
        """Validate the units list."""
        if not isinstance(units, list):
            self.errors.append(ValidationError(
                'error',
                f'{path}.units',
                f'Units must be a list, got {type(units).__name__}'
            ))
            return
        
        if len(units) == 0:
            self.errors.append(ValidationError(
                'error',
                f'{path}.units',
                'Group must have at least one unit'
            ))
            return
        
        # Validate each unit
        for idx, unit in enumerate(units):
            self._validate_unit(f'{path}.units[{idx}]', unit)
    
    def _validate_unit(self, path: str, unit: Any) -> None:
        """Validate a single unit."""
        if not isinstance(unit, dict):
            self.errors.append(ValidationError(
                'error',
                path,
                f'Unit must be a dictionary, got {type(unit).__name__}'
            ))
            return
        
        # Check required fields
        if 'type' not in unit:
            self.errors.append(ValidationError(
                'error',
                path,
                'Missing required field "type"'
            ))
        elif not isinstance(unit['type'], str):
            self.errors.append(ValidationError(
                'error',
                f'{path}.type',
                f'Unit type must be a string, got {type(unit["type"]).__name__}'
            ))
    
    def _check_group_structure(self, path: str, group: Dict) -> None:
        """Check for potential structural issues in a group."""
        common_group_keys = {
            'name', 'type', 'units', 'uncontrolled', 'route', 'start_type',
            'x', 'y', 'alt', 'speed', 'on_ground'
        }
        
        for key in group.keys():
            if key not in common_group_keys and not key.startswith('__'):
                self.errors.append(ValidationError(
                    'info',
                    f'{path}',
                    f'Unusual field "{key}" detected',
                    'This might be a typo or extracted metadata that should be removed'
                ))
    
    def validate(self) -> Tuple[bool, List[ValidationError]]:
        """
        Run all validation checks.
        
        Returns:
            Tuple of (is_valid, errors_list)
            is_valid is False if there are any errors (not warnings)
        """
        self.errors = []
        
        # Load and parse YAML
        if not self.load_yaml():
            return False, self.errors
        
        # Validate structure
        if self.data:
            self.validate_structure()
        
        # Check if there are any actual errors (not warnings)
        has_errors = any(e.level == 'error' for e in self.errors)
        
        return not has_errors, self.errors
    
    def get_summary(self) -> str:
        """
        Get a summary of validation results.
        
        Returns:
            Formatted summary string
        """
        error_count = sum(1 for e in self.errors if e.level == 'error')
        warning_count = sum(1 for e in self.errors if e.level == 'warning')
        info_count = sum(1 for e in self.errors if e.level == 'info')
        
        summary = f"Validation Summary: {error_count} error(s), {warning_count} warning(s), {info_count} info message(s)"
        return summary
    
    def get_report(self) -> str:
        """
        Get a detailed report of all validation issues.
        
        Returns:
            Formatted report string
        """
        if not self.errors:
            return "✓ No issues found. YAML file is valid."
        
        report = self.get_summary() + "\n\n"
        
        # Group errors by level
        errors_by_level = {'error': [], 'warning': [], 'info': []}
        for error in self.errors:
            errors_by_level[error.level].append(error)
        
        # Format errors
        for level in ['error', 'warning', 'info']:
            if errors_by_level[level]:
                report += f"\n{level.upper()}S:\n"
                report += "-" * (len(level) + 2) + "\n"
                for error in errors_by_level[level]:
                    report += str(error) + "\n\n"
        
        return report



class AircraftGroupsInjectorWorker:
    """
    Worker class that injects aircraft groups from YAML into a DCS mission.
    Automatically validates YAML before injection.
    """
    
    def __init__(self, input_yaml: Path, target_mission: Path, output_mission: Path):
        """
        Initialize the injector.
        
        Args:
            input_yaml: Path to the YAML file containing aircraft groups
            target_mission: Path to the target .miz mission file
            output_mission: Path where to save the modified mission
        """
        self.input_yaml = input_yaml
        self.target_mission = target_mission
        self.output_mission = output_mission
        self.yaml_data: Optional[Dict] = None
        self.dcs_mission: Optional[DcsMission] = None
        self.injection_log: List[str] = []
        self.validator: Optional[AircraftGroupsYAMLValidator] = None
    
    def validate_yaml(self, silent: bool = False) -> Tuple[bool, str]:
        """
        Validate the YAML file.
        
        Args:
            silent: If True, suppress info messages
            
        Returns:
            Tuple of (is_valid, report_text)
        """
        if not silent:
            logger.info(f"Validating YAML file {self.input_yaml}")
        
        self.validator = AircraftGroupsYAMLValidator(self.input_yaml)
        is_valid, errors = self.validator.validate()
        report = self.validator.get_report()
        
        if not silent:
            if is_valid:
                logger.info("YAML validation successful")
            else:
                logger.warning("YAML validation failed")
        
        return is_valid, report
    
    def load_yaml_data(self, silent: bool = False) -> bool:
        """
        Load the YAML file containing aircraft groups.
        
        Args:
            silent: If True, suppress info messages
            
        Returns:
            True if loading succeeded, False otherwise
        """
        try:
            if not silent:
                logger.info(f"Loading YAML file {self.input_yaml}")
            
            with open(self.input_yaml, 'r', encoding='utf-8') as f:
                self.yaml_data = yaml.safe_load(f)
            
            if self.yaml_data is None:
                logger.error("YAML file is empty", exception_type=ValueError)
                return False
            
            if not silent:
                logger.info("YAML file loaded successfully")
            return True
        
        except FileNotFoundError:
            logger.error(f"YAML file not found: {self.input_yaml}", exception_type=FileNotFoundError)
            return False
        except Exception as e:
            logger.error(f"Failed to load YAML file: {str(e)}", exception_type=type(e))
            return False
    
    def read_mission(self, silent: bool = False) -> bool:
        """
        Load the target mission from the .miz file.
        
        Args:
            silent: If True, suppress info messages
            
        Returns:
            True if loading succeeded, False otherwise
        """
        try:
            if not silent:
                logger.info(f"Reading mission file {self.target_mission}")
            
            self.dcs_mission = read_miz(self.target_mission)
            
            if not self.dcs_mission.mission_content:
                logger.error("Failed to read mission content", exception_type=ValueError)
                return False
            
            if not silent:
                logger.info("Mission file loaded successfully")
            return True
        
        except Exception as e:
            logger.error(f"Failed to read mission file: {str(e)}", exception_type=type(e))
            return False
    
    def _get_or_create_coalition_structure(self, coalition_name: str) -> Dict:
        """
        Get or create the coalition structure in the mission.
        
        Args:
            coalition_name: Name of the coalition ('blue' or 'red')
            
        Returns:
            The coalition dictionary
        """
        if 'coalition' not in self.dcs_mission.mission_content:
            self.dcs_mission.mission_content['coalition'] = {}
        
        coalitions = self.dcs_mission.mission_content['coalition']
        
        if coalition_name not in coalitions:
            coalitions[coalition_name] = {'country': []}
        
        return coalitions[coalition_name]
    
    def _get_or_create_country(self, coalition: Dict, country_name: str) -> Dict:
        """
        Get or create a country structure in a coalition.
        
        Args:
            coalition: The coalition dictionary
            country_name: Name of the country
            
        Returns:
            The country dictionary
        """
        if 'country' not in coalition:
            coalition['country'] = []
        
        countries = coalition['country']
        
        # Find existing country
        for country in countries:
            if country.get('name') == country_name:
                return country
        
        # Create new country
        new_country = {
            'name': country_name,
            'plane': {'group': []},
            'helicopter': {'group': []}
        }
        countries.append(new_country)
        return new_country
    
    def _ensure_aircraft_category(self, country: Dict, category: str) -> List:
        """
        Ensure the aircraft category exists in a country.
        
        Args:
            country: The country dictionary
            category: 'plane' or 'helicopter'
            
        Returns:
            The groups list for the category
        """
        if category == 'planes':
            category = 'plane'
        elif category == 'helicopters':
            category = 'helicopter'
        
        if category not in country:
            country[category] = {'group': []}
        
        if 'group' not in country[category]:
            country[category]['group'] = []
        
        return country[category]['group']
    
    def inject_groups(self, mode: str = 'add', silent: bool = False) -> InjectionResult:
        """
        Inject aircraft groups from YAML into the mission.
        
        Args:
            mode: 'add' to add new groups, 'replace' to replace existing ones with same name
            silent: If True, suppress info messages
            
        Returns:
            InjectionResult with injection status
        """
        if not self.dcs_mission:
            return InjectionResult(
                success=False,
                groups_injected=0,
                message="Mission not loaded. Call read_mission() first."
            )
        
        if not self.yaml_data:
            return InjectionResult(
                success=False,
                groups_injected=0,
                message="YAML data not loaded. Call load_yaml_data() first."
            )
        
        total_injected = 0
        injection_errors = []
        
        # Process each aircraft category
        for category in ['airplanes', 'helicopters']:
            if category not in self.yaml_data:
                continue
            
            category_data = self.yaml_data[category]
            if 'coalitions' not in category_data:
                continue
            
            coalitions = category_data['coalitions']
            
            # Process each coalition
            for coalition_name, coalition_groups in coalitions.items():
                try:
                    coalition = self._get_or_create_coalition_structure(coalition_name)
                    
                    # Process each country
                    for country_name, country_groups in coalition_groups.items():
                        country = self._get_or_create_country(coalition, country_name)
                        
                        # Convert category name for mission structure
                        mission_category = 'plane' if category == 'airplanes' else 'helicopter'
                        groups_list = self._ensure_aircraft_category(country, mission_category)
                        
                        # Process each group
                        for group_name, group_data in country_groups.items():
                            try:
                                # Check if group already exists (for replace mode)
                                existing_idx = None
                                if mode == 'replace':
                                    for idx, existing_group in enumerate(groups_list):
                                        if existing_group.get('name') == group_name:
                                            existing_idx = idx
                                            break
                                
                                # Make a deep copy to avoid modifying the original
                                group_copy = copy.deepcopy(group_data)
                                
                                if existing_idx is not None:
                                    # Replace existing group
                                    groups_list[existing_idx] = group_copy
                                    log_msg = f"Replaced group {group_name} in {coalition_name}/{country_name}/{category}"
                                else:
                                    # Add new group
                                    groups_list.append(group_copy)
                                    log_msg = f"Injected group {group_name} into {coalition_name}/{country_name}/{category}"
                                
                                self.injection_log.append(log_msg)
                                total_injected += 1
                                
                                if not silent:
                                    logger.debug(log_msg)
                            
                            except Exception as e:
                                error_msg = f"Failed to inject group {group_name}: {str(e)}"
                                injection_errors.append(error_msg)
                                self.injection_log.append(error_msg)
                                logger.warning(error_msg)
                
                except Exception as e:
                    error_msg = f"Failed to process coalition {coalition_name}: {str(e)}"
                    injection_errors.append(error_msg)
                    self.injection_log.append(error_msg)
                    logger.warning(error_msg)
        
        # Prepare result
        if total_injected > 0:
            message = f"Successfully injected {total_injected} group(s)"
            if injection_errors:
                message += f" with {len(injection_errors)} error(s)"
                return InjectionResult(
                    success=False,
                    groups_injected=total_injected,
                    message=message,
                    details={'errors': injection_errors}
                )
            else:
                if not silent:
                    logger.info(message)
                return InjectionResult(
                    success=True,
                    groups_injected=total_injected,
                    message=message
                )
        else:
            return InjectionResult(
                success=False,
                groups_injected=0,
                message="No groups were injected",
                details={'errors': injection_errors} if injection_errors else {}
            )
    
    def write_mission(self, silent: bool = False) -> bool:
        """
        Write the modified mission to the output file.
        
        Args:
            silent: If True, suppress info messages
            
        Returns:
            True if writing succeeded, False otherwise
        """
        if not self.dcs_mission:
            logger.error("No mission to write", exception_type=ValueError)
            return False
        
        try:
            if not silent:
                logger.info(f"Writing modified mission to {self.output_mission}")
            
            write_miz(self.dcs_mission, Path(self.output_mission))
            
            if not silent:
                logger.info("Mission written successfully")
            return True
        
        except Exception as e:
            logger.error(f"Failed to write mission: {str(e)}", exception_type=type(e))
            return False
    
    def inject(
        self,
        mode: str = 'add',
        silent: bool = False,
        interactive: bool = False
    ) -> InjectionResult:
        """
        Main injection workflow with automatic validation.
        
        Validates the YAML file first, and only proceeds with injection if validation succeeds.
        
        Args:
            mode: 'add' to add new groups, 'replace' to replace existing ones
            silent: If True, suppress output messages
            interactive: If True, show detailed progress information
            
        Returns:
            InjectionResult with injection status
        """
        # STEP 1: Validate YAML
        with spinner_context(f"Validating {self.input_yaml}...", silent=silent):
            is_valid, validation_report = self.validate_yaml(silent)
        
        # Display validation report
        console.print("\n" + validation_report)
        
        # If validation fails, stop here
        if not is_valid:
            console.print("[bold red]✗ YAML validation failed. Please fix the errors before injection.[/bold red]")
            return InjectionResult(
                success=False,
                groups_injected=0,
                message="YAML validation failed",
                details={'validation_report': validation_report}
            )
        
        console.print("[bold green]✓ YAML validation successful![/bold green]\n")
        
        # STEP 2: Load YAML
        with spinner_context(f"Loading {self.input_yaml}...", silent=silent):
            if not self.load_yaml_data(silent):
                return InjectionResult(
                    success=False,
                    groups_injected=0,
                    message="Failed to load YAML file"
                )
        
        # STEP 3: Load mission
        with spinner_context(f"Reading {self.target_mission}...", silent=silent):
            if not self.read_mission(silent):
                return InjectionResult(
                    success=False,
                    groups_injected=0,
                    message="Failed to read mission file"
                )
        
        # STEP 4: Inject groups
        with spinner_context("Injecting groups...", silent=silent):
            result = self.inject_groups(mode, silent)
        
        # STEP 5: Write mission
        with spinner_context("Writing modified mission...", silent=silent):
            if result.success or result.groups_injected > 0:
                if not self.write_mission(silent):
                    result.success = False
                    result.message = "Groups were injected but writing mission failed"
        
        return result
    
    def display_results(self, result: InjectionResult, verbose: bool = False) -> None:
        """
        Display injection results in a formatted way.
        
        Args:
            result: The InjectionResult to display
            verbose: If True, show detailed injection log
        """
        # Display main result
        status_icon = "✅" if result.success else "⚠️"
        status_color = "bright_green" if result.success else "bright_yellow"
        
        header_text = Text(f"{status_icon} INJECTION RESULT", style=f"bold {status_color}")
        console.print(Panel(header_text, border_style=status_color, padding=(1, 2)))
        
        # Display summary
        console.print(f"[bold]Groups injected:[/bold] [bright_yellow]{result.groups_injected}[/bright_yellow]")
        console.print(f"[bold]Message:[/bold] {result.message}")
        
        # Display errors if any
        if result.details and 'errors' in result.details and result.details['errors']:
            console.print("\n[bold bright_red]Errors:[/bold bright_red]")
            for error in result.details['errors']:
                console.print(f"  [red]✗[/red] {error}")
        
        # Display injection log if verbose
        if verbose and self.injection_log:
            console.print("\n[bold]Injection Log:[/bold]")
            for log_entry in self.injection_log:
                console.print(f"  {log_entry}")


class AircraftGroupsExtractorWorker:
    """
    Worker class that extracts aircraft groups matching a regexp from a DCS mission
    and writes them to a YAML file in aircraft-templates.yaml format.
    """
    
    # Properties to exclude from extraction
    PROPERTIES_TO_EXCLUDE = {
        'radio',   # Radio configuration (mission-specific, not needed for injection)
        'Radio'    # Radio configuration (uppercase variant)
    }
    
    def __init__(self, input_mission: Path, output_yaml: Path, group_name_pattern: str):
        """
        Initialize the extractor.
        
        Args:
            input_mission: Path to the input .miz mission file
            output_yaml: Path to the output YAML file
            group_name_pattern: Regular expression pattern to match group names
        """
        self.input_mission = input_mission
        self.output_yaml = output_yaml
        self.group_name_pattern = re.compile(group_name_pattern)
        self.dcs_mission: Optional[DcsMission] = None
        self.extracted_templates = {
            "airplanes": {"coalitions": {}},
            "helicopters": {"coalitions": {}}
        }
        self.matched_groups: Dict[str, Dict] = {}  # Store matched groups for interactive selection
    
    def read_mission(self, silent: bool = False) -> None:
        """Load the mission from the .miz file."""
        if not silent:
            logger.info(f"Reading mission file {self.input_mission}")
        self.dcs_mission = read_miz(self.input_mission)
        
        if not self.dcs_mission.mission_content:
            logger.error("Failed to read mission content", exception_type=ValueError)
    
    def find_matching_groups(self, silent: bool = False) -> None:
        """Find all plane groups matching the pattern and store them for selection."""
        if not self.dcs_mission:
            logger.error("Mission not loaded. Call read_mission() first.", exception_type=RuntimeError)
            return
        
        coalitions_dict = self.dcs_mission.mission_content.get("coalition")
        if not coalitions_dict:
            logger.warning("No coalitions found in mission")
            return
        
        matched_count = 0
        
        for coalition_name in coalitions_dict.keys():
            coalition_data = coalitions_dict[coalition_name]
            countries_list = coalition_data.get("country", [])
            
            if not countries_list:
                continue
            
            for country_dict in countries_list:
                country_name = country_dict.get("name", "Unknown")
                
                # Process plane groups
                if plane_data := country_dict.get("plane", {}):
                    groups_list = plane_data.get("group", [])
                    for group in groups_list:
                        group_name = group.get("name", "")
                        
                        # Check if group name matches pattern
                        if self.group_name_pattern.search(group_name):
                            matched_count += 1
                            logger.debug(f"Matched plane group: {group_name}")
                            group_key = f"{coalition_name}/{country_name}/airplanes/{group_name}"
                            self.matched_groups[group_key] = {
                                "group": group,
                                "aircraft_category": "airplanes",
                                "coalition_name": coalition_name,
                                "country_name": country_name,
                                "group_name": group_name
                            }
                
                # Process helicopter groups
                if helo_data := country_dict.get("helicopter", {}):
                    groups_list = helo_data.get("group", [])
                    for group in groups_list:
                        group_name = group.get("name", "")
                        
                        # Check if group name matches pattern
                        if self.group_name_pattern.search(group_name):
                            matched_count += 1
                            logger.debug(f"Matched helicopter group: {group_name}")
                            group_key = f"{coalition_name}/{country_name}/helicopters/{group_name}"
                            self.matched_groups[group_key] = {
                                "group": group,
                                "aircraft_category": "helicopters",
                                "coalition_name": coalition_name,
                                "country_name": country_name,
                                "group_name": group_name
                            }
        
        if not silent:
            logger.info(f"Found {matched_count} matching group(s)")
    
    def select_groups_interactively(self) -> int:
        """
        Display matched groups and let user select which ones to include.
        
        Returns:
            Number of groups selected
        """
        if not self.matched_groups:
            logger.warning("No groups found to select from")
            return 0
        
        # Display header with style
        header_text = Text("🎯 GROUP SELECTION", style="bold bright_cyan")
        header_text.append(" - Select groups to extract", style="cyan")
        console.print(Panel(header_text, border_style="cyan", padding=(1, 2)))
        
        group_list = list(self.matched_groups.keys())
        selected_groups: Dict[str, Dict] = {}
        
        for idx, group_key in enumerate(group_list, 1):
            group_info = self.matched_groups[group_key]
            coalition = group_info["coalition_name"]
            country = group_info["country_name"]
            aircraft_type = group_info["aircraft_category"]
            group_name = group_info["group_name"]
            units_count = len(group_info["group"].get("units", []))
            
            # Display group number and name
            console.print(f"[bold bright_yellow]▶ [{idx}][/bold bright_yellow] [bold bright_green]{group_name}[/bold bright_green]")
            
            # Coalition with color coding
            coalition_color = "bright_blue" if coalition == "blue" else "bright_red"
            coalition_icon = "🔵" if coalition == "blue" else "🔴"
            console.print(f"  {coalition_icon} [{coalition_color}]{coalition.upper()}[/{coalition_color}] | [white]{country}[/white]")
            
            # Aircraft type and units
            aircraft_emoji = "✈️ " if aircraft_type == "airplanes" else "🚁 "
            console.print(f"  {aircraft_emoji}[bright_cyan]{aircraft_type}[/bright_cyan] | [bright_yellow]{units_count} unit(s)[/bright_yellow]")
            
            # Get unit types info
            unit_types = set()
            if units := group_info["group"].get("units", []):
                for unit in units:
                    if unit_type := unit.get("type"):
                        unit_types.add(unit_type)
            
            if unit_types:
                types_text = ", ".join(sorted(unit_types))
                console.print(f"  [bright_magenta]📋 Types:[/bright_magenta] [white]{types_text}[/white]")
            
            # Ask user for confirmation using standard input
            console.print("  [bold bright_cyan]❓ Include this group?[/bold bright_cyan] (y/n/skip) [[bright_yellow]skip[/bright_yellow]]: ", end="")
            response = input().strip().lower()
            
            if response in ("y", "yes"):
                selected_groups[group_key] = group_info
                console.print("  [bold bright_green]✅ Included[/bold bright_green]\n")
            elif response in ("", "skip",):
                console.print("  [dim bright_black]⊘ Skipped[/dim bright_black]\n")
                # Continue to next group
            else:
                console.print("  [bold bright_red]❌ Excluded[/bold bright_red]\n")
        
        # Add selected groups to templates
        for group_info in selected_groups.values():
            self._add_group_to_templates(
                group_info["group"],
                group_info["aircraft_category"],
                group_info["coalition_name"],
                group_info["country_name"]
            )
        
        # Display summary with style
        summary_text = Text(f"📊 Summary: {len(selected_groups)} group(s) selected", style="bold bright_yellow")
        console.print(Panel(summary_text, border_style="yellow", padding=(1, 2)))
        
        return len(selected_groups)
    
    def extract_plane_groups(self, silent: bool = False) -> None:
        """Extract plane groups matching the pattern (non-interactive mode)."""
        if not self.dcs_mission:
            logger.error("Mission not loaded. Call read_mission() first.", exception_type=RuntimeError)
            return
        
        self.find_matching_groups(silent)
        
        # Add all matched groups to templates (old behavior)
        for group_info in self.matched_groups.values():
            self._add_group_to_templates(
                group_info["group"],
                group_info["aircraft_category"],
                group_info["coalition_name"],
                group_info["country_name"]
            )
    
    def _clean_group_data(self, group: Dict) -> Dict:
        """
        Clean group data by removing properties that should not be extracted.
        Recursively removes excluded properties from all nested structures.
        
        Args:
            group: Original group dictionary from mission
            
        Returns:
            Cleaned copy of the group without excluded properties
        """
        cleaned_group = copy.deepcopy(group)
        self._remove_excluded_properties(cleaned_group)
        return cleaned_group
    
    def _remove_excluded_properties(self, obj: Any) -> None:
        """
        Recursively remove excluded properties from a nested data structure.
        Modifies the object in place.
        
        Args:
            obj: Dictionary, list, or other object to clean
        """
        if isinstance(obj, dict):
            # Remove excluded properties at this level
            for prop in self.PROPERTIES_TO_EXCLUDE:
                obj.pop(prop, None)
            
            # Recursively clean nested dictionaries and lists
            for value in obj.values():
                self._remove_excluded_properties(value)
        elif isinstance(obj, list):
            # Recursively clean each item in the list
            for item in obj:
                self._remove_excluded_properties(item)
    
    def _add_group_to_templates(
        self,
        group: Dict,
        aircraft_category: str,
        coalition_name: str,
        country_name: str
    ) -> None:
        """Add a group to the extracted templates with full details."""
        group_name = group.get("name", "Unknown")
        
        # Initialize coalition structure if needed
        if coalition_name not in self.extracted_templates[aircraft_category]["coalitions"]:
            self.extracted_templates[aircraft_category]["coalitions"][coalition_name] = {}
        
        # Initialize country if needed
        if country_name not in self.extracted_templates[aircraft_category]["coalitions"][coalition_name]:
            self.extracted_templates[aircraft_category]["coalitions"][coalition_name][country_name] = {}
        
        # Clean the group data and store it
        cleaned_group = self._clean_group_data(group)
        self.extracted_templates[aircraft_category]["coalitions"][coalition_name][country_name][group_name] = cleaned_group
    
    def write_yaml(self, silent: bool = False) -> None:
        """Write the extracted templates to a YAML file."""
        if not silent:
            logger.info(f"Writing extracted templates to {self.output_yaml}")
        
        try:
            # Create output directory if it doesn't exist
            self.output_yaml.parent.mkdir(parents=True, exist_ok=True)
            
            with open(self.output_yaml, 'w') as yaml_file:
                yaml.dump(
                    self.extracted_templates,
                    yaml_file,
                    default_flow_style=False,
                    sort_keys=True,
                    allow_unicode=True
                )
            
            if not silent:
                logger.info(f"Successfully wrote templates to {self.output_yaml}")
        except Exception as e:
            logger.error(f"Failed to write YAML file: {str(e)}", exception_type=IOError)
    
    def extract(self, silent: bool = False, interactive: bool = False) -> None:
        """
        Main extraction workflow.
        
        Args:
            silent: If True, suppress output messages
            interactive: If True, allow user to select which groups to include
        """
        with spinner_context(f"Reading {self.input_mission}...", silent=silent):
            self.read_mission(silent)
        
        with spinner_context("Finding matching groups...", silent=silent):
            if self.dcs_mission:
                self.find_matching_groups(silent)
        
        groups_selected = 0
        
        if interactive:
            # In interactive mode, user selects groups
            groups_selected = self.select_groups_interactively()
        else:
            # Non-interactive: add all matched groups
            with spinner_context("Extracting groups...", silent=silent):
                for group_info in self.matched_groups.values():
                    self._add_group_to_templates(
                        group_info["group"],
                        group_info["aircraft_category"],
                        group_info["coalition_name"],
                        group_info["country_name"]
                    )
            groups_selected = len(self.matched_groups)
        
        # Check if any groups were selected/extracted
        if groups_selected == 0:
            # Display warning message instead of writing empty file
            warning_text = Text("[!] No Groups Extracted", style="bold bright_yellow")
            warning_text.append("\nNo groups were selected for extraction.", style="yellow")
            console.print(Panel(warning_text, border_style="yellow", padding=(1, 2)))
            logger.warning("No groups were extracted - file was not created")
            return
        
        with spinner_context("Writing templates...", silent=silent):
            self.write_yaml(silent)
