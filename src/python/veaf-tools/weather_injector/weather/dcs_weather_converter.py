"""DCS weather conversion from METAR data."""

from typing import Dict, Any, Optional
import json
import re

from veaf_libs.logger import logger

try:
    from avwx import Metar
    AVWX_AVAILABLE = True
except ImportError:
    AVWX_AVAILABLE = False


class DCSWeatherConverter:
    """Convert METAR strings to DCS weather table format."""
    
    # DCS weather cloud types
    CLOUD_TYPES = {
        "clear": 0,
        "few": 1,
        "scattered": 2,
        "broken": 3,
        "overcast": 4,
    }
    
    @staticmethod
    def to_dcs_lua_table(
        metar_string: str = "",
        airport_icao: str = "",
        temperature_celsius: Optional[float] = None,
        wind_speed_mps: Optional[float] = None,
        wind_direction_degrees: Optional[float] = None,
        visibility_meters: Optional[float] = None,
        cloud_coverage: Optional[str] = None,
        cloud_height_meters: Optional[float] = None,
        fog_enabled: bool = False,
        fog_density: float = 0.0,
        fog_thickness_meters: float = 200.0,
    ) -> Dict[str, Any]:
        """
        Convert weather parameters to DCS mission weather table.
        
        Supports three weather input methods:
        1. metar_string: User-provided METAR string (parsed with regex)
        2. airport_icao: Airport code to fetch live METAR from avwx-engine
        3. Individual parameters: Manual weather values
        
        Priority: metar_string > airport_icao > individual parameters > defaults
        
        Args:
            metar_string: METAR weather string (provided manually)
            airport_icao: Airport ICAO code to fetch live METAR from avwx
            temperature_celsius: Temperature override
            wind_speed_mps: Wind speed in m/s override
            wind_direction_degrees: Wind direction override
            visibility_meters: Visibility in meters override
            cloud_coverage: Cloud type ("clear", "few", "scattered", "broken", "overcast")
            cloud_height_meters: Cloud base altitude in meters
            fog_enabled: Enable fog effect
            fog_density: Fog density (0.0-1.0)
            fog_thickness_meters: Fog vertical thickness
        
        Returns:
            Dictionary representing DCS weather table structure
        """
        try:
            weather = {}
            
            # Priority 1: Use provided METAR string
            if metar_string:
                weather = _extract_metar_values(metar_string)
            # Priority 2: Fetch live weather from avwx if airport code provided
            elif airport_icao:
                weather = _fetch_live_metar(airport_icao)
            
            # Apply parameter overrides
            if temperature_celsius is not None:
                weather["temperature"] = temperature_celsius
            if wind_speed_mps is not None:
                weather["wind_speed"] = wind_speed_mps
            if wind_direction_degrees is not None:
                weather["wind_direction"] = wind_direction_degrees
            if visibility_meters is not None:
                weather["visibility"] = visibility_meters
            if cloud_coverage:
                weather["cloud_type"] = DCSWeatherConverter.CLOUD_TYPES.get(
                    cloud_coverage.lower(), 0
                )
            if cloud_height_meters is not None:
                weather["cloud_height"] = cloud_height_meters
            
            # Build DCS weather table
            dcs_weather = {
                "atmosphere": {
                    "temperature_celsius": weather.get("temperature", 15.0),
                    "wind": {
                        "speed_mps": weather.get("wind_speed", 5.0),
                        "direction_degrees": weather.get("wind_direction", 0.0),
                    },
                    "visibility_meters": weather.get("visibility", 10000.0),
                    "clouds": {
                        "type": weather.get("cloud_type", 0),
                        "base_altitude_meters": weather.get("cloud_height", 2000.0),
                        "density": 0.0,
                    },
                },
                "fog": {
                    "enabled": fog_enabled,
                    "density": fog_density,
                    "thickness_meters": fog_thickness_meters,
                },
            }
            
            logger.debug(f"Converted weather: {json.dumps(dcs_weather, indent=2)}")
            return dcs_weather
        
        except Exception as e:
            logger.error(f"Failed to convert weather: {e}")
            raise


def _fetch_live_metar(airport_icao: str) -> Dict[str, Any]:
    """
    Fetch live METAR data from avwx-engine by airport ICAO code.
    
    Args:
        airport_icao: Airport ICAO code (e.g., "OSDI", "KJFK")
    
    Returns:
        Dictionary with keys: temperature, wind_speed, wind_direction, 
        visibility, cloud_type, cloud_height
    """
    result = {
        "temperature": 15.0,  # Default
        "wind_speed": 5.0,     # m/s
        "wind_direction": 0.0, # degrees
        "visibility": 10000.0, # meters
        "cloud_type": 0,       # Clear
        "cloud_height": 2000.0, # meters
    }
    
    if not airport_icao or not AVWX_AVAILABLE:
        if not AVWX_AVAILABLE:
            logger.warning("avwx-engine not available. Cannot fetch live METAR. Using defaults.")
        return result
    
    try:
        logger.debug(f"Fetching live METAR for airport {airport_icao} from avwx-engine")
        metar = Metar(airport_icao)
        
        if metar.temperature and metar.temperature.value is not None:
            result["temperature"] = metar.temperature.value
        
        if metar.wind_speed and metar.wind_speed.value is not None:
            # avwx returns knots, convert to m/s
            result["wind_speed"] = metar.wind_speed.value / 1.944
        
        if metar.wind_direction and metar.wind_direction.value is not None:
            result["wind_direction"] = float(metar.wind_direction.value)
        
        if metar.visibility and metar.visibility[0].value is not None:
            result["visibility"] = metar.visibility[0].value
        
        # Process clouds
        if metar.clouds:
            for cloud in metar.clouds:
                if cloud[0]:
                    cloud_coverage = cloud[0].lower()
                    if cloud_coverage in ["skc", "clr"]:
                        result["cloud_type"] = 0  # Clear
                    elif cloud_coverage == "few":
                        result["cloud_type"] = 1
                    elif cloud_coverage == "sct":
                        result["cloud_type"] = 2  # Scattered
                    elif cloud_coverage == "bkn":
                        result["cloud_type"] = 3  # Broken
                    elif cloud_coverage == "ovc":
                        result["cloud_type"] = 4  # Overcast
                
                if cloud[1]:
                    result["cloud_height"] = float(cloud[1].value)
                    break  # Use first cloud layer
        
        logger.debug(f"Successfully fetched METAR for {airport_icao}: {result}")
    except Exception as e:
        logger.warning(f"Failed to fetch live METAR for {airport_icao}: {e}. Using defaults.")
    
    return result


def _extract_metar_values(metar_string: str) -> Dict[str, Any]:
    """
    Extract weather values from METAR string using regex-based parsing.
    
    Args:
        metar_string: METAR weather string (e.g., "OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018")
    
    Returns:
        Dictionary with keys: temperature, wind_speed, wind_direction, 
        visibility, cloud_type, cloud_height
    """
    result = {
        "temperature": 15.0,  # Default
        "wind_speed": 5.0,     # m/s
        "wind_direction": 0.0, # degrees
        "visibility": 10000.0, # meters
        "cloud_type": 0,       # Clear
        "cloud_height": 2000.0, # meters
    }
    
    if not metar_string:
        return result
    
    # Use fallback regex-based parsing for provided METAR strings
    result = _fallback_metar_parsing(metar_string, result)
    
    return result


def _fallback_metar_parsing(metar_string: str, defaults: Dict[str, Any]) -> Dict[str, Any]:
    """
    Fallback regex-based METAR parsing for common patterns.
    
    Used when avwx-engine is not available or parsing fails.
    Extracts basic values from standard METAR format.
    
    Args:
        metar_string: METAR weather string
        defaults: Default values to use
    
    Returns:
        Dictionary with extracted weather values
    """
    result = defaults.copy()
    
    if not metar_string:
        return result
    
    parts = metar_string.split()
    
    for i, part in enumerate(parts):
        # Temperature/Dewpoint: "15/10" format
        if "/" in part and i > 0:
            with_temp = part.split("/")[0]
            if with_temp.lstrip("-").isdigit():
                try:
                    result["temperature"] = float(with_temp)
                except ValueError:
                    pass
        
        # Wind: "27015G25KT" or "27015KT" format (direction speed[gust]KT/MPS)
        if "KT" in part or "MPS" in part:
            match = re.match(r"(\d{3})(\d{2})(?:G(\d{2}))?", part)
            if match:
                try:
                    result["wind_direction"] = float(match.group(1))
                    speed = float(match.group(2))
                    # Convert knots to m/s (1 knot = 0.51444 m/s)
                    result["wind_speed"] = speed * 0.51444
                except ValueError:
                    pass
        
        # Visibility: "9999" format (meters) or "10SM" (statute miles)
        if part.isdigit() and len(part) == 4:
            try:
                result["visibility"] = float(part)
            except ValueError:
                pass
        
        # Cloud coverage groups: "FEW010", "SCT025", "BKN040", "OVC100"
        cloud_match = re.match(r"(SKC|CLR|FEW|SCT|BKN|OVC)(\d{3})?", part)
        if cloud_match:
            coverage = cloud_match.group(1)
            altitude = cloud_match.group(2)
            
            if coverage in ["SKC", "CLR"]:
                result["cloud_type"] = 0
            elif coverage == "FEW":
                result["cloud_type"] = 1
            elif coverage == "SCT":
                result["cloud_type"] = 2
            elif coverage == "BKN":
                result["cloud_type"] = 3
            elif coverage == "OVC":
                result["cloud_type"] = 4
            
            if altitude:
                try:
                    # Altitude in METAR is in hundreds of feet
                    result["cloud_height"] = float(altitude) * 100 * 0.3048  # Convert to meters
                except ValueError:
                    pass
    
    return result
