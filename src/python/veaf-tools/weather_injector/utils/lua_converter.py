"""Convert legacy Lua configuration to YAML format."""

from pathlib import Path
from typing import Dict, Any, Optional, List
import re
import yaml

from veaf_libs.logger import logger


class LuaToYamlConverter:
    """Convert legacy Lua weather and time configuration to YAML format."""
    
    @staticmethod
    def convert_file(lua_file: Path, output_file: Optional[Path] = None) -> Optional[Path]:
        """
        Convert a Lua configuration file to YAML.
        
        Args:
            lua_file: Path to the Lua configuration file
            output_file: Output YAML file path (defaults to lua_file with .yaml extension)
        
        Returns:
            Path to created YAML file, or None if conversion failed
        """
        try:
            if not lua_file.exists():
                logger.error(f"Lua configuration file not found: {lua_file}")
                return None
            
            # Read Lua file
            with open(lua_file, "r") as f:
                lua_content = f.read()
            
            # Parse Lua configuration
            config_dict = LuaToYamlConverter._parse_lua_config(lua_content)
            
            if not config_dict:
                logger.error("Failed to parse Lua configuration")
                return None
            
            # Determine output file
            if output_file is None:
                output_file = lua_file.parent / f"{lua_file.stem}.yaml"
            else:
                output_file = Path(output_file)
            
            # Write YAML file
            with open(output_file, "w") as f:
                yaml.dump(config_dict, f, default_flow_style=False, sort_keys=False)
            
            logger.info(f"Converted Lua configuration to YAML: {output_file}")
            return output_file
        
        except Exception as e:
            logger.error(f"Failed to convert Lua configuration: {e}", exc_info=True)
            return None
    
    @staticmethod
    def _parse_lua_config(lua_content: str) -> Optional[Dict[str, Any]]:
        """
        Parse legacy Lua configuration format.
        
        Expected format:
        ```lua
        weatherAndTime = {
          position = {
            lat = 33.5,
            lon = 35.5,
            tz = "Asia/Damascus"
          },
          moments = {
            dawn = "sunrise+30*60",
            noon = "12:00",
            dusk = "sunset-10*60"
          },
          variableForMetar = "METAR",
          targets = {
            {
              version = "dawn",
              moment = "dawn",
              weather = "METAR OSDI 151420Z ...",
              dontSetToday = false,
              dontSetTodayYear = false,
              clearsky = false
            },
            ...
          }
        }
        ```
        """
        try:
            config = {}
            
            # Parse position
            position = LuaToYamlConverter._extract_table(lua_content, "position")
            if position:
                config["position"] = {
                    "latitude": LuaToYamlConverter._get_number(position, "lat"),
                    "longitude": LuaToYamlConverter._get_number(position, "lon"),
                    "timezone": LuaToYamlConverter._get_string(position, "tz")
                }
            
            # Parse moments (rename to moments if needed)
            moments = LuaToYamlConverter._extract_table(lua_content, "moments")
            if moments:
                config["moments"] = LuaToYamlConverter._parse_string_table(moments)
            
            # Parse variable for METAR
            variable_for_metar = LuaToYamlConverter._get_string(lua_content, "variableForMetar")
            if variable_for_metar:
                config["variableForMetar"] = variable_for_metar
            
            # Parse targets (convert to versions)
            targets = LuaToYamlConverter._extract_list(lua_content, "targets")
            if targets:
                config["versions"] = []
                for target in targets:
                    version = {
                        "name": LuaToYamlConverter._get_string(target, "version")
                    }
                    
                    # Add optional fields
                    if moment := LuaToYamlConverter._get_string(target, "moment"):
                        version["moment"] = moment
                    if time := LuaToYamlConverter._get_number(target, "time"):
                        version["time"] = time
                    if weather := LuaToYamlConverter._get_string(target, "weather"):
                        version["weather"] = weather
                    if date := LuaToYamlConverter._get_string(target, "date"):
                        version["date"] = date
                    
                    config["versions"].append(version)
            
            return config if config else None
        
        except Exception as e:
            logger.error(f"Error parsing Lua configuration: {e}")
            return None
    
    @staticmethod
    def _extract_table(content: str, table_name: str) -> Optional[str]:
        """Extract a Lua table from content."""
        # Match: table_name = { ... }
        pattern = rf"{table_name}\s*=\s*\{{"
        match = re.search(pattern, content)
        if not match:
            return None
        
        start = match.end() - 1
        brace_count = 0
        in_string = False
        string_char = None
        escape_next = False
        
        for i in range(start, len(content)):
            char = content[i]
            
            # Handle escape sequences
            if escape_next:
                escape_next = False
                continue
            
            if char == "\\" and in_string:
                escape_next = True
                continue
            
            # Handle string literals
            if char in ('"', "'") and not escape_next:
                if not in_string:
                    in_string = True
                    string_char = char
                elif char == string_char:
                    in_string = False
                continue
            
            # Count braces outside strings
            if not in_string:
                if char == "{":
                    brace_count += 1
                elif char == "}":
                    brace_count -= 1
                    if brace_count == 0:
                        return content[start:i+1]
        
        return None
    
    @staticmethod
    def _extract_list(content: str, list_name: str) -> List[str]:
        """Extract list of tables from content."""
        pattern = rf"{list_name}\s*=\s*\{{\s*"
        match = re.search(pattern, content)
        if not match:
            return []
        
        start = match.end() - 1
        tables = []
        brace_count = 0
        in_string = False
        string_char = None
        table_start = None
        
        i = start
        while i < len(content):
            char = content[i]
            
            # Handle escape sequences
            if i > 0 and content[i-1] == "\\":
                i += 1
                continue
            
            # Handle string literals
            if char in ('"', "'"):
                if not in_string:
                    in_string = True
                    string_char = char
                elif char == string_char:
                    in_string = False
            
            # Process braces outside strings
            if not in_string:
                if char == "{":
                    brace_count += 1
                    if brace_count == 1:
                        table_start = i
                elif char == "}":
                    brace_count -= 1
                    if brace_count == 0 and table_start is not None:
                        tables.append(content[table_start:i+1])
                        table_start = None
                    elif brace_count == -1:
                        break
            
            i += 1
        
        return tables
    
    @staticmethod
    def _get_string(content: str, key: str) -> Optional[str]:
        """Extract string value from Lua content."""
        # Match: key = "value" or key = 'value'
        pattern = rf'{key}\s*=\s*["\']([^"\']*)["\']'
        match = re.search(pattern, content)
        return match.group(1) if match else None
    
    @staticmethod
    def _get_number(content: str, key: str) -> Optional[float]:
        """Extract number value from Lua content."""
        # Match: key = number
        pattern = rf'{key}\s*=\s*([-+]?\d*\.?\d+)'
        match = re.search(pattern, content)
        if not match:
            return None
        
        value = match.group(1)
        try:
            return float(value) if '.' in value else int(value)
        except ValueError:
            return None
    
    @staticmethod
    def _get_boolean(content: str, key: str) -> bool:
        """Extract boolean value from Lua content."""
        # Match: key = true/false
        pattern = rf'{key}\s*=\s*(true|false)'
        match = re.search(pattern, content)
        return match.group(1).lower() == "true" if match else False
    
    @staticmethod
    def _parse_string_table(content: str) -> Dict[str, str]:
        """Parse a Lua table of key=value strings."""
        result = {}
        
        # Match: key = "value" patterns
        pattern = r'(\w+)\s*=\s*["\']([^"\']*)["\']'
        matches = re.finditer(pattern, content)
        
        for match in matches:
            key = match.group(1)
            value = match.group(2)
            result[key] = value
        
        return result
