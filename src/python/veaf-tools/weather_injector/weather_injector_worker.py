"""Main worker for creating mission versions with weather and time modifications."""

from datetime import date as dt_date, datetime, timedelta
from pathlib import Path
from typing import Optional, Dict, Any, List
import yaml

from veaf_libs.logger import logger
from mission_tools import read_miz, write_miz

from .models import MissionConfig, VersionConfig
from .utils import SolarCalculator, TimeExpressionParser
from .weather import DCSWeatherConverter


class WeatherInjectorWorker:
    """
    Create multiple versions of a DCS mission with different weather and times.
    
    Workflow:
    1. Load configuration from JSON file
    2. For each version config:
       a. Load base mission
       b. Calculate solar times if position specified
       c. Parse and apply time/date modifications
       d. Apply weather modifications
       e. Write output mission file
    """
    
    def __init__(self, config_file: Path, mission_file: Path, output_dir: Optional[Path] = None):
        """
        Initialize worker.
        
        Args:
            config_file: Path to YAML configuration file
            mission_file: Path to base mission .miz file
            output_dir: Output directory for mission files (defaults to config directory)
        """
        self.config_file = Path(config_file)
        self.mission_file = Path(mission_file)
        self.output_dir = Path(output_dir) if output_dir else self.config_file.parent
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.config: Optional[MissionConfig] = None
        self.mission_data: Optional[Dict[str, Any]] = None
        self.solar_times: Dict[str, int] = {}
    
    def work(self) -> List[Path]:
        """
        Execute batch mission creation.
        
        Returns:
            List of created mission file paths
        """
        logger.info(f"Loading configuration from {self.config_file}")
        self.config = self._load_configuration()
        
        if not self.config:
            logger.error("Failed to load configuration")
            return []
        
        logger.info(f"Configuration loaded: {len(self.config.versions)} versions to create")
        
        # Calculate solar times if position specified
        if self.config.position:
            self._calculate_solar_times()
        
        # Process each version
        created_files = []
        for i, version in enumerate(self.config.versions, 1):
            try:
                logger.info(f"[{i}/{len(self.config.versions)}] Creating version: {version.name}")
                output_path = self._create_mission_version(version)
                created_files.append(output_path)
                logger.info(f"Created: {output_path}")
            except Exception as e:
                logger.error(f"Failed to create version '{version.name}': {e}")
                continue
        
        logger.info(f"Created {len(created_files)} mission files")
        return created_files
    
    def _load_configuration(self) -> Optional[MissionConfig]:
        """Load and parse YAML configuration file."""
        try:
            with open(self.config_file, "r") as f:
                config_dict = yaml.safe_load(f)
            
            return MissionConfig.from_dict(config_dict)
        
        except FileNotFoundError:
            logger.error(f"Configuration file not found: {self.config_file}")
            return None
        except yaml.YAMLError as e:
            logger.error(f"Invalid YAML in configuration file: {e}")
            return None
        except Exception as e:
            logger.error(f"Failed to load configuration: {e}")
            return None
    
    def _calculate_solar_times(self) -> None:
        """Calculate sunrise/sunset for the configuration position."""
        if not self.config or not self.config.position:
            return
        
        try:
            # Parse base_date if specified, otherwise use today
            if self.config.base_date:
                target_date = self._parse_date(self.config.base_date)
            else:
                target_date = dt_date.today()
            
            self.solar_times = SolarCalculator.get_sun_times(
                self.config.position,
                target_date
            )
            logger.debug(f"Solar times calculated: {self.solar_times}")
        except Exception as e:
            logger.error(f"Failed to calculate solar times: {e}")
            self.solar_times = {}
    
    def _create_mission_version(self, version: VersionConfig) -> Path:
        """
        Create a single mission version.
        
        Args:
            version: Version configuration
        
        Returns:
            Path to created mission file
        """
        # Load base mission
        base_mission_path = self.mission_file if self.mission_file.is_absolute() else self.config_file.parent / self.mission_file
        if not base_mission_path.exists():
            raise FileNotFoundError(f"Base mission not found: {base_mission_path}")
        
        logger.debug(f"Loading base mission: {base_mission_path}")
        self.mission_data = read_miz(str(base_mission_path))
        
        # Debug: Log the structure of start_time
        st = self.mission_data.mission_content.get("start_time")
        logger.debug(f"start_time type: {type(st)}, value: {st}")
        
        # Apply modifications
        if version.time or version.date:
            self._update_mission_time_and_date(version)
        
        if version.weather or version.metar:
            self._inject_weather(version)
        
        # Write output
        output_path = self.output_dir / f"{version.name}.miz"
        logger.debug(f"Writing mission to: {output_path}")
        write_miz(mission=self.mission_data, miz_file_path=output_path)
        
        return output_path
    
    def _update_mission_time_and_date(self, version: VersionConfig) -> None:
        """Update mission start time and date."""
        if not self.mission_data:
            return
        
        try:
            # Parse time expression
            if version.time:
                time_seconds = TimeExpressionParser.parse(
                    version.time,
                    self.solar_times.get("sunrise"),
                    self.solar_times.get("sunset"),
                )
                logger.debug(f"Parsed time '{version.time}' = {time_seconds}s")
                self._set_mission_time(time_seconds)
            
            # Update date
            if version.date:
                mission_date = self._parse_date(version.date)
                logger.debug(f"Parsed date '{version.date}' = {mission_date}")
                self._set_mission_date(mission_date)
        
        except Exception as e:
            logger.error(f"Failed to update mission time/date: {e}")
            raise
    
    def _inject_weather(self, version: VersionConfig) -> None:
        """Inject weather into mission."""
        if not self.mission_data:
            return
        
        try:
            converter = DCSWeatherConverter()
            
            if version.metar:
                # User provided METAR string
                weather = converter.to_dcs_lua_table(metar_string=version.metar)
            elif version.airport_icao:
                # Fetch live weather from avwx using airport ICAO code
                weather = converter.to_dcs_lua_table(airport_icao=version.airport_icao)
            else:
                # Use individual weather parameters
                weather = converter.to_dcs_lua_table(
                    metar_string="",
                    temperature_celsius=version.weather.get("temperature") if version.weather else None,
                    wind_speed_mps=version.weather.get("wind_speed") if version.weather else None,
                    wind_direction_degrees=version.weather.get("wind_direction") if version.weather else None,
                    visibility_meters=version.weather.get("visibility") if version.weather else None,
                    cloud_coverage=version.weather.get("cloud_type") if version.weather else None,
                    cloud_height_meters=version.weather.get("cloud_height") if version.weather else None,
                    fog_enabled=version.weather.get("fog_enabled", False) if version.weather else False,
                )
            
            self._set_mission_weather(weather)
            logger.debug(f"Weather injected")
        
        except Exception as e:
            logger.error(f"Failed to inject weather: {e}")
            raise
    
    def _set_mission_time(self, seconds: int) -> None:
        """
        Set mission start time in seconds since midnight.
        
        Args:
            seconds: Time in seconds (0-86400)
        """
        if not self.mission_data:
            return
        
        mission_content = self.mission_data.mission_content
        mission_content["start_time"] = seconds
        logger.debug(f"Set mission start time to {seconds}s ({seconds//3600:02d}:{(seconds%3600)//60:02d})")
    
    def _set_mission_date(self, mission_date: dt_date) -> None:
        """
        Set mission start date.
        
        Args:
            mission_date: Date object
        """
        if not self.mission_data:
            return
        
        mission_content = self.mission_data.mission_content
        if "date" not in mission_content:
            mission_content["date"] = {}
        
        mission_content["date"]["Day"] = mission_date.day
        mission_content["date"]["Month"] = mission_date.month
        mission_content["date"]["Year"] = mission_date.year
        
        logger.debug(f"Set mission date to {mission_date}")
    
    def _set_mission_weather(self, weather: Dict[str, Any]) -> None:
        """
        Set mission weather.
        
        Args:
            weather: Weather dictionary from DCSWeatherConverter
        """
        if not self.mission_data:
            return
        
        mission_content = self.mission_data.mission_content
        if "weather" not in mission_content:
            mission_content["weather"] = {}
        
        # Merge weather data into mission
        mission_content["weather"].update(weather)
        logger.debug("Weather set in mission")
    
    @staticmethod
    def _parse_date(date_expr: str) -> dt_date:
        """
        Parse date expression to date object.
        
        Supports:
        - "YYYY-MM-DD" format
        - "today" / "tomorrow" / "yesterday"
        - "+1" / "-2" (days from today)
        
        Args:
            date_expr: Date expression string
        
        Returns:
            Date object
        """
        expr = date_expr.strip().lower()
        today = dt_date.today()
        
        # Keyword dates
        if expr == "today":
            return today
        elif expr == "tomorrow":
            return today + timedelta(days=1)
        elif expr == "yesterday":
            return today - timedelta(days=1)
        
        # Relative dates: "+1", "-2"
        if expr.startswith("+") or expr.startswith("-"):
            try:
                days = int(expr)
                return today + timedelta(days=days)
            except ValueError:
                pass
        
        # ISO format: "2024-03-15"
        try:
            return dt_date.fromisoformat(expr)
        except ValueError:
            pass
        
        raise ValueError(f"Cannot parse date expression: {date_expr}")
