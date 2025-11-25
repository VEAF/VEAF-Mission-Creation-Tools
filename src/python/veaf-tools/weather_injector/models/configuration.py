"""Configuration data models for weather and time versions."""

from dataclasses import dataclass, field
from typing import Dict, Optional, Any
from pathlib import Path


@dataclass
class Position:
    """Geographic position for solar calculations."""
    latitude: float
    longitude: float
    timezone: str


@dataclass
class VersionConfig:
    """Configuration for a single mission version."""
    name: str                             # Output filename (without .miz)
    time: Optional[str] = None            # Time expression: "HH:MM", "sunrise", "sunrise+30*60", etc.
    date: Optional[str] = None            # Date expression: "2024-03-15", "today", "+1", etc.
    metar: Optional[str] = None           # METAR weather string (provided manually)
    airport_icao: Optional[str] = None    # Airport ICAO code to fetch live METAR from avwx
    weather: Optional[Dict[str, Any]] = None  # Manual weather parameters


@dataclass
class MissionConfig:
    """Complete mission configuration."""
    position: Optional[Position] = None   # Geographic position for solar calculations
    base_date: Optional[str] = None       # Base date for all versions
    versions: list = field(default_factory=list)  # List[VersionConfig]
    
    @classmethod
    def from_dict(cls, data: Dict) -> 'MissionConfig':
        """Parse configuration from dictionary (loaded from YAML or dict)."""
        # Parse position if present
        position = None
        if "position" in data and data["position"]:
            pos_data = data["position"]
            position = Position(
                latitude=float(pos_data["latitude"]),
                longitude=float(pos_data["longitude"]),
                timezone=str(pos_data["timezone"])
            )
        
        # Parse versions
        versions = []
        for version_data in data.get("versions", []):
            version_config = VersionConfig(
                name=version_data["name"],
                time=version_data.get("time"),
                date=version_data.get("date"),
                metar=version_data.get("metar"),
                airport_icao=version_data.get("airport_icao"),
                weather=version_data.get("weather")
            )
            versions.append(version_config)
        
        return cls(
            position=position,
            base_date=data.get("base_date"),
            versions=versions
        )
