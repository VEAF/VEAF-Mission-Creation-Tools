"""
Classes for managing radio presets data from YAML files.
"""

from dataclasses import dataclass
from PIL import Image, ImageDraw, ImageFont
from typing import Optional, Dict, Any
from typing_extensions import Self
import io
import yaml


@dataclass
class Fonts:
      preset: ImageFont.FreeTypeFont
      title: ImageFont.FreeTypeFont
      collection_title: ImageFont.FreeTypeFont
    
@dataclass
class RadioChannel:
    """
    Represents a radio channel preset with frequency, name, and modulation.
    """
    freq: float
    number: Optional[int] = None
    name: Optional[str] = None
    mod: Optional[int] = 0
    
    def __post_init__(self):
        """Validate and normalize the channel data after initialization."""
        # Validate frequency is provided (as it's mandatory)
        if self.freq is None:
            raise ValueError("Frequency is mandatory for a RadioChannel")

        # Convert frequency to float if it's a string
        if isinstance(self.freq, str):
            try:
                object.__setattr__(self, 'freq', float(self.freq))
            except ValueError as e:
                raise ValueError(f"Invalid frequency value: {self.freq}") from e

        # Validate frequency range (typical radio frequencies)
        if self.freq < 0 or self.freq > 100000:
            raise ValueError(f"Frequency out of valid range (0-100000): {self.freq}")

        # Validate modulation type
        if not isinstance(self.mod, int):
            raise TypeError("Modulation must be an integer")

        # Validate modulation range (typically 0-3 for DCS)
        if self.mod < 0 or self.mod > 3:
            raise ValueError(f"Modulation out of valid range (0-3): {self.mod}")

        # Validate name type if provided
        if self.name is not None and not isinstance(self.name, str):
            raise TypeError("Name must be a string")
    
    def __str__(self) -> str:
        """Return a human-readable string representation of the channel."""
        parts = [f"freq={self.freq}"]
        if self.name:
            parts.append(f"name='{self.name}'")
        if self.mod != 0:
            parts.append(f"mod={self.mod}")
        return f"RadioChannel({', '.join(parts)})"
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the channel to a dictionary representation.
        
        Returns:
            dict: Dictionary with all non-None attributes
        """
        result = {"freq": self.freq}
        if self.name is not None:
            result["name"] = self.name
        if self.mod != 0:
            result["mod"] = self.mod
        return result
    
    @classmethod
    def from_dict(cls, channel_name, data: Dict[str, Any], radio_type: Optional[str] = None) -> 'RadioChannel':
        """
        Create a RadioChannel instance from a dictionary.
        
        Args:
            channel_name: The name of the channel
            data: Dictionary containing channel data
            radio_type: The type of the radio (e.g., 'uhf', 'vhf', 'fm') to select the appropriate frequency
            
        Returns:
            RadioChannel: New instance
            
        Raises:
            ValueError: If frequency is missing from data
        """
        freq = None
        if "freq" in data:
            freq = float(data["freq"])
        elif "freqs" in data:
            if radio_type is None:
                raise ValueError(f"Radio type is required to select frequency from freqs: {data}")
            freqs = data["freqs"]
            if radio_type in freqs:
                freq = float(freqs[radio_type])
            else:
                raise ValueError(f"Frequency for radio type '{radio_type}' not found in freqs: {freqs}")
        else:
            raise ValueError(f"Frequency is mandatory in channel data: {data}")

        number = int(channel_name) if channel_name.isdigit() else int(channel_name.split('_')[-1])
        return cls(
            freq=freq,
            name=data.get("title", f"Channel {number}"),
            number=number,
            mod=int(data.get("mod", 0))
        )


@dataclass
class Radio:
    """
    Represents a radio with multiple channels.
    """
    name: str
    title: str
    channels: Dict[str, RadioChannel]
    
    def __post_init__(self):
        """Validate the radio data after initialization."""
        if not isinstance(self.name, str):
            raise TypeError("Radio name must be a string")
        
        if not isinstance(self.channels, dict):
            raise TypeError("Channels must be a dictionary")
        
        for channel_name, channel in self.channels.items():
            if not isinstance(channel_name, str):
                raise TypeError("Channel names must be strings")
            if not isinstance(channel, RadioChannel):
                raise TypeError(f"Channel '{channel_name}' must be a RadioChannel instance")
    
    def __str__(self) -> str:
        """Return a human-readable string representation of the radio."""
        return f"Radio(name='{self.name}', channels={len(self.channels)} channels)"
    
    def add_channel(self, name: str, channel: RadioChannel) -> None:
        """
        Add a channel to the radio.
        
        Args:
            name: The name of the channel
            channel: The RadioChannel instance
        """
        if not isinstance(name, str):
            raise TypeError("Channel name must be a string")
        if not isinstance(channel, RadioChannel):
            raise TypeError("Channel must be a RadioChannel instance")
        
        self.channels[name] = channel
    
    def get_channel(self, name: str) -> Optional[RadioChannel]:
        """
        Get a channel by name.
        
        Args:
            name: The name of the channel
            
        Returns:
            RadioChannel: The channel if found, None otherwise
        """
        return self.channels.get(name)
    
    def remove_channel(self, name: str) -> bool:
        """
        Remove a channel by name.
        
        Args:
            name: The name of the channel
            
        Returns:
            bool: True if the channel was removed, False if it didn't exist
        """
        if name in self.channels:
            del self.channels[name]
            return True
        return False
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the radio to a dictionary representation.
        
        Returns:
            dict: Dictionary representation of the radio
        """
        return {
            "channelsNames": {
                int(name) if name.isdigit() else int(name.split('_')[-1]): channel.name for name, channel in self.channels.items()
            },
            "modulations": {
                int(name) if name.isdigit() else int(name.split('_')[-1]): channel.mod for name, channel in self.channels.items()
            },
            "channels": {
                int(name) if name.isdigit() else int(name.split('_')[-1]): channel.freq for name, channel in self.channels.items()
            }
        }
    
    
    @classmethod
    def from_dict(cls, name: str, data: Dict[str, Any], channels_definition: Optional['ChannelsDefinition'] = None) -> 'Radio':
        """
        Create a Radio instance from a dictionary.
        
        Args:
            name: The name of the radio
            data: Dictionary containing radio data
            channels_definition: Optional ChannelsDefinition for resolving aliases
            
        Returns:
            Radio: New instance
        """
        title = data.get("title", "Unnamed Radio")
        radio_type = data.get("type")
        if "channels" not in data:
            raise ValueError(f"Radio data must contain 'channels' key : {data}")

        channels = {}
        for channel_name, channel_alias_or_data in data["channels"].items():
            if isinstance(channel_alias_or_data, str):
                # It's an alias, resolve it
                if channels_definition is None:
                    raise ValueError(f"Channels definition is required to resolve alias '{channel_alias_or_data}' for channel '{channel_name}'")
                channel_data = channels_definition.get_channel_data(channel_alias_or_data)
                if channel_data is None:
                    raise ValueError(f"Channel alias '{channel_alias_or_data}' not found in channels definition")
            elif isinstance(channel_alias_or_data, dict):
                if "channel" in channel_alias_or_data:
                    # Override mode: base on alias with overrides
                    alias = channel_alias_or_data["channel"]
                    if channels_definition is None:
                        raise ValueError(f"Channels definition is required to resolve alias '{alias}' for channel '{channel_name}'")
                    base_data = channels_definition.get_channel_data(alias)
                    if base_data is None:
                        raise ValueError(f"Channel alias '{alias}' not found in channels definition")
                    # Merge base data with overrides
                    channel_data = base_data.copy()
                    for key, value in channel_alias_or_data.items():
                        if key != "channel":
                            channel_data[key] = value
                else:
                    # Complete channel definition
                    channel_data = channel_alias_or_data
            else:
                raise ValueError(f"Invalid channel definition for '{channel_name}': must be string or dict")
            channels[channel_name] = RadioChannel.from_dict(channel_name, channel_data, radio_type)
        return cls(name=name, title=title, channels=channels)


@dataclass
class ChannelsDefinition:
    """
    Manages all channel definitions.
    """
    channels: Dict[str, Dict[str, Any]]

    def __post_init__(self):
        """Validate the channels definition data after initialization."""
        if not isinstance(self.channels, dict):
            raise TypeError("Channels must be a dictionary")

        for channel_name, channel_data in self.channels.items():
            if not isinstance(channel_name, str):
                raise TypeError("Channel names must be strings")
            if not isinstance(channel_data, dict):
                raise TypeError(f"Channel data for '{channel_name}' must be a dictionary")

    def get_channel_data(self, alias: str) -> Optional[Dict[str, Any]]:
        """
        Get channel data by alias or title.

        Args:
            alias: The alias of the channel
            
        Returns:
            Dict: The channel data if found, None otherwise
        """
        # First try by alias
        if alias in self.channels:
            return self.channels[alias]
        # Then try by title
        for channel_data in self.channels.values():
            if channel_data.get("title") == alias:
                return channel_data
        return None

    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the channels definition to a dictionary representation.
        
        Returns:
            dict: Dictionary representation of the channels definition
        """
        return {"channels": self.channels}

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ChannelsDefinition':
        """
        Create a ChannelsDefinition instance from a dictionary.
        
        Args:
            data: Dictionary containing channels definition data
            
        Returns:
            ChannelsDefinition: New instance
        """
        channels = data.get("channels", {})
        return cls(channels=channels)


@dataclass
class RadiosDefinition:
    """
    Manages all radio definitions.
    """
    radios: Dict[str, Radio]
    
    def __post_init__(self):
        """Validate the radios definition data after initialization."""
        if not isinstance(self.radios, dict):
            raise TypeError("Radios must be a dictionary")
        
        for radio_name, radio in self.radios.items():
            if not isinstance(radio_name, str):
                raise TypeError("Radio names must be strings")
            if not isinstance(radio, Radio):
                raise TypeError(f"Radio '{radio_name}' must be a Radio instance")
    
    def __str__(self) -> str:
        """Return a human-readable string representation of the radios definition."""
        return f"RadiosDefinition(radios={len(self.radios)} radios)"
    
    def add_radio(self, name: str, radio: Radio) -> None:
        """
        Add a radio definition.
        
        Args:
            name: The name of the radio
            radio: The Radio instance
        """
        if not isinstance(name, str):
            raise TypeError("Radio name must be a string")
        if not isinstance(radio, Radio):
            raise TypeError("Radio must be a Radio instance")
        
        self.radios[name] = radio
    
    def get_radio(self, name: str) -> Optional[Radio]:
        """
        Get a radio by name.
        
        Args:
            name: The name of the radio
            
        Returns:
            Radio: The radio if found, None otherwise
        """
        return self.radios.get(name)
    
    def remove_radio(self, name: str) -> bool:
        """
        Remove a radio by name.
        
        Args:
            name: The name of the radio
            
        Returns:
            bool: True if the radio was removed, False if it didn't exist
        """
        if name in self.radios:
            del self.radios[name]
            return True
        return False
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the radios definition to a dictionary representation.
        
        Returns:
            dict: Dictionary representation of the radios definition
        """
        return {
            name: radio.to_dict() for name, radio in self.radios.items()
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any], channels_definition: Optional['ChannelsDefinition'] = None) -> 'RadiosDefinition':
        """
        Create a RadiosDefinition instance from a dictionary.
        
        Args:
            data: Dictionary containing radios definition data
            channels_definition: Optional ChannelsDefinition for resolving aliases
            
        Returns:
            RadiosDefinition: New instance
        """
        radios = {
            radio_name: Radio.from_dict(radio_name, radio_data, channels_definition)
            for radio_name, radio_data in data.items()
        }
        return cls(radios=radios)


@dataclass
class PresetCollection:
    """
    Represents a collection of radio aliases (a preset collection).
    """
    name: str
    title: str
    radios: Dict[str, str]  # radio_name -> radio_alias
    used_in_mission: bool = False  # Indicates if this collection is used in the mission

    def __post_init__(self):
        """Validate the preset collection data after initialization."""
        if not isinstance(self.name, str):
            raise TypeError("Preset collection name must be a string")
        
        if not isinstance(self.radios, dict):
            raise TypeError("Radios must be a dictionary")
        
        for radio_name, radio_alias in self.radios.items():
            if not isinstance(radio_name, str):
                raise TypeError("Radio names must be strings")
            if not isinstance(radio_alias, str):
                raise TypeError(f"Radio alias for '{radio_name}' must be a string")
    
    def __str__(self) -> str:
        """Return a human-readable string representation of the preset collection."""
        return f"PresetCollection(name='{self.name}', radios={len(self.radios)} radios)"
    
    def add_radio(self, name: str, radio_alias: str) -> None:
        """
        Add a radio alias to the preset collection.
        
        Args:
            name: The name of the radio slot
            radio_alias: The alias of the radio definition
        """
        if not isinstance(name, str):
            raise TypeError("Radio name must be a string")
        if not isinstance(radio_alias, str):
            raise TypeError("Radio alias must be a string")
        
        self.radios[name] = radio_alias
    
    def get_radio_alias(self, name: str) -> Optional[str]:
        """
        Get a radio alias by name.
        
        Args:
            name: The name of the radio slot
            
        Returns:
            str: The radio alias if found, None otherwise
        """
        return self.radios.get(name)
    
    def remove_radio(self, name: str) -> bool:
        """
        Remove a radio by name.
        
        Args:
            name: The name of the radio slot
            
        Returns:
            bool: True if the radio was removed, False if it didn't exist
        """
        if name in self.radios:
            del self.radios[name]
            return True
        return False
    
    def get_resolved_radios(self, radios_definition: 'RadiosDefinition') -> Dict[str, Radio]:
        """
        Get the resolved radios by looking up aliases in radios_definition.
        
        Args:
            radios_definition: The RadiosDefinition instance
            
        Returns:
            Dict[str, Radio]: Dictionary of radio slot name to Radio instance
        """
        resolved = {}
        for slot_name, alias in self.radios.items():
            radio = radios_definition.get_radio(alias)
            if radio is None:
                raise ValueError(f"Radio alias '{alias}' not found in radios definition for slot '{slot_name}'")
            resolved[slot_name] = radio
        return resolved
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the preset collection to a dictionary representation.
        
        Returns:
            dict: Dictionary representation of the preset collection
        """
        return {
            "title": self.title,
            "radios": self.radios
        }
    
    @classmethod
    def from_dict(cls, name: str, data: Dict[str, Any], radios_definition: Optional['RadiosDefinition'] = None) -> 'PresetCollection':
        """
        Create a PresetCollection instance from a dictionary.
        
        Args:
            name: The name of the preset collection
            data: Dictionary containing preset collection data
            radios_definition: Optional RadiosDefinition for validation (not used in creation)
            
        Returns:
            PresetCollection: New instance
        """
        title = data.get("title", "Unnamed preset collection")
        radios = data.get("radios", {})
        return cls(name=name, title=title, radios=radios)


@dataclass
class PresetsDefinition:
    """
    Manages all preset collections.
    """
    collections: Dict[str, PresetCollection]
    
    def __post_init__(self):
        """Validate the presets definition data after initialization."""
        if not isinstance(self.collections, dict):
            raise TypeError("Collections must be a dictionary")
        
        for collection_name, collection in self.collections.items():
            if not isinstance(collection_name, str):
                raise TypeError("Collection names must be strings")
            if not isinstance(collection, PresetCollection):
                raise TypeError(f"Collection '{collection_name}' must be a PresetCollection instance")
    
    def __str__(self) -> str:
        """Return a human-readable string representation of the presets definition."""
        return f"PresetsDefinition(collections={len(self.collections)} collections)"
    
    def add_collection(self, name: str, collection: PresetCollection) -> None:
        """
        Add a preset collection.
        
        Args:
            name: The name of the collection
            collection: The PresetCollection instance
        """
        if not isinstance(name, str):
            raise TypeError("Collection name must be a string")
        if not isinstance(collection, PresetCollection):
            raise TypeError("Collection must be a PresetCollection instance")
        
        self.collections[name] = collection
    
    def get_collection(self, name: str) -> Optional[PresetCollection]:
        """
        Get a preset collection by name.
        
        Args:
            name: The name of the collection
            
        Returns:
            PresetCollection: The collection if found, None otherwise
        """
        return self.collections.get(name)
    
    def remove_collection(self, name: str) -> bool:
        """
        Remove a preset collection by name.
        
        Args:
            name: The name of the collection
            
        Returns:
            bool: True if the collection was removed, False if it didn't exist
        """
        if name in self.collections:
            del self.collections[name]
            return True
        return False
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the presets definition to a dictionary representation.
        
        Returns:
            dict: Dictionary representation of the presets definition
        """
        return {
            name: collection.to_dict() for name, collection in self.collections.items()
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any], radios_definition: Optional['RadiosDefinition'] = None) -> 'PresetsDefinition':
        """
        Create a PresetsDefinition instance from a dictionary.
        
        Args:
            data: Dictionary containing presets definition data
            radios_definition: Optional RadiosDefinition for resolving aliases
            
        Returns:
            PresetsDefinition: New instance
        """
        collections = {
            collection_name: PresetCollection.from_dict(
                collection_name, collection_data, radios_definition
            )
            for collection_name, collection_data in data.items()
        }
        return cls(collections=collections)


@dataclass
class PresetAssignment:
    """
    Represents assignments of presets to coalitions.
    """
    assignments: Dict[str, Dict[str, Dict[str, str]]]
    
    def __post_init__(self):
        """Validate the preset assignment data after initialization."""
        if not isinstance(self.assignments, dict):
            raise TypeError("Assignments must be a dictionary")
    
    def __str__(self) -> str:
        """Return a human-readable string representation of the preset assignment."""
        coalition_count = len(self.assignments)
        return f"PresetAssignment(coalitions={coalition_count})"
    
    def set_assignment(self, coalition: str, aircraft_type: str, group_type: str, preset: str) -> None:
        """
        Set a preset assignment.
        
        Args:
            coalition: The coalition name (e.g., 'blue', 'red')
            aircraft_type: The aircraft type (e.g., 'airplanes', 'helicopters')
            group_type: The group type (e.g., 'all')
            preset: The preset name or 'none'
        """
        if coalition not in self.assignments:
            self.assignments[coalition] = {}
        if aircraft_type not in self.assignments[coalition]:
            self.assignments[coalition][aircraft_type] = {}
        
        self.assignments[coalition][aircraft_type][group_type] = preset
    
    def get_assignment(self, coalition: str, aircraft_type: str, group_type: str) -> Optional[str]:
        """
        Get a preset assignment.
        
        Args:
            coalition: The coalition name
            aircraft_type: The aircraft type
            group_type: The group type
            
        Returns:
            str: The preset name if found, None otherwise
        """
        return self.assignments.get(coalition, {}).get(aircraft_type, {}).get(group_type)
    
    def remove_assignment(self, coalition: str, aircraft_type: str, group_type: str) -> bool:
        """
        Remove a preset assignment.
        
        Args:
            coalition: The coalition name
            aircraft_type: The aircraft type
            group_type: The group type
            
        Returns:
            bool: True if the assignment was removed, False if it didn't exist
        """
        if (coalition in self.assignments and 
            aircraft_type in self.assignments[coalition] and
            group_type in self.assignments[coalition][aircraft_type]):
            del self.assignments[coalition][aircraft_type][group_type]
            return True
        return False
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the preset assignment to a dictionary representation.
        
        Returns:
            dict: Dictionary representation of the preset assignment
        """
        return self.assignments
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'PresetAssignment':
        """
        Create a PresetAssignment instance from a dictionary.
        
        Args:
            data: Dictionary containing preset assignment data
            
        Returns:
            PresetAssignment: New instance
        """
        return cls(assignments=data)


@dataclass
class PresetsManager:
    """
    Main interface for loading and managing presets data.
    """
    channels_definition: Optional[ChannelsDefinition] = None
    radios_definition: Optional[RadiosDefinition] = None
    presets_definition: Optional[PresetsDefinition] = None
    presets_assignment: Optional[PresetAssignment] = None
    presets_images: Optional[Dict[str, io.BytesIO]] = None
    _cached_fonts: Optional['Fonts'] = None

    def __post_init__(self):
        """Initialize the presets manager."""
        if self.channels_definition is None:
            self.channels_definition = ChannelsDefinition(channels={})
        if self.radios_definition is None:
            self.radios_definition = RadiosDefinition(radios={})
        if self.presets_definition is None:
            self.presets_definition = PresetsDefinition(collections={})
        if self.presets_assignment is None:
            self.presets_assignment = PresetAssignment(assignments={})
    
    def __str__(self) -> str:
        """Return a human-readable string representation of the presets manager."""
        channel_count = len(self.channels_definition.channels) if self.channels_definition else 0
        radio_count = len(self.radios_definition.radios) if self.radios_definition else 0
        collection_count = len(self.presets_definition.collections) if self.presets_definition else 0
        coalition_count = len(self.presets_assignment.assignments) if self.presets_assignment else 0
        return f"PresetsManager(channels={channel_count}, radios={radio_count}, collections={collection_count}, coalitions={coalition_count})"
    
    def load_from_yaml(self, file_path: str) -> None:
        """
        Load presets data from a YAML file.
        
        Args:
            file_path: Path to the YAML file
        """
        try:
            with open(file_path, 'r') as file:
                data = yaml.safe_load(file)

            # Load channels definition
            if "channels_definition" in data:
                self.channels_definition = ChannelsDefinition.from_dict(data["channels_definition"])
            else:
                self.channels_definition = ChannelsDefinition(channels={})

            # Load radios definition
            if "radios_definition" in data:
                self.radios_definition = RadiosDefinition.from_dict(data["radios_definition"], self.channels_definition)
            else:
                self.radios_definition = RadiosDefinition(radios={})

            # Load presets definition
            if "presets_definition" in data:
                self.presets_definition = PresetsDefinition.from_dict(data["presets_definition"], self.radios_definition)
            else:
                self.presets_definition = PresetsDefinition(collections={})

            # Load presets assignment
            if "presets_assignments" in data:
                self.presets_assignment = PresetAssignment.from_dict(data["presets_assignments"])
            else:
                self.presets_assignment = PresetAssignment(assignments={})

        except FileNotFoundError as e:
            raise FileNotFoundError(f"YAML file not found: {file_path}") from e
        except yaml.YAMLError as e:
            raise ValueError(f"Error parsing YAML file {file_path}: {str(e)}") from e
        except Exception as e:
            raise RuntimeError(f"Error loading presets from {file_path}: {str(e)}") from e
    
    def save_to_yaml(self, file_path: str) -> None:
        """
        Save presets data to a YAML file.
        
        Args:
            file_path: Path to the YAML file
        """
        try:
            data = {}
            
            # Save channels definition
            if self.channels_definition:
                data["channels_definition"] = self.channels_definition.to_dict()
            
            # Save radios definition
            if self.radios_definition:
                data["radios_definition"] = self.radios_definition.to_dict()
            
            # Save presets definition
            if self.presets_definition:
                data["presets_definition"] = self.presets_definition.to_dict()
            
            # Save presets assignment
            if self.presets_assignment:
                data["presets_assignments"] = self.presets_assignment.to_dict()
            
            with open(file_path, 'w') as file:
                yaml.dump(data, file, default_flow_style=False, allow_unicode=True)
                
        except Exception as e:
            raise RuntimeError(f"Error saving presets to {file_path}: {str(e)}") from e
    
    def get_preset_collection(self, name: str) -> Optional[PresetCollection]:
        """
        Get a preset collection by name.
        
        Args:
            name: The name of the collection
            
        Returns:
            PresetCollection: The collection if found, None otherwise
        """
        if self.presets_definition:
            return self.presets_definition.get_collection(name)
        return None
    
    def get_preset_assignment(self, coalition: str, aircraft_type: str, group_type: str = "all") -> Optional[str]:
        """
        Get a preset assignment.
        
        Args:
            coalition: The coalition name
            aircraft_type: The aircraft type
            group_type: The group type (default: "all")
            
        Returns:
            str: The preset name if found, None otherwise
        """
        if self.presets_assignment:
            return self.presets_assignment.get_assignment(coalition, aircraft_type, group_type)
        return None
    
    def validate(self) -> bool:
        """
        Validate the presets data.
        
        Returns:
            bool: True if valid, False otherwise
        """
        # Check if presets definition exists
        if not self.presets_definition:
            return False
        
        # Check if presets assignment exists
        if not self.presets_assignment:
            return False
        
        # Validate assignments reference existing collections
        for coalition, aircraft_types in self.presets_assignment.assignments.items():
            for aircraft_type, group_types in aircraft_types.items():
                for group_type, preset_name in group_types.items():
                    if preset_name != "none" and preset_name not in self.presets_definition.collections:
                        return False
        
        return True
    
    def get_fonts(self) -> Self:
        if self._cached_fonts is None:
            try:
                preset_font = ImageFont.truetype("arial.ttf", 18)
                title_font = ImageFont.truetype("arial.ttf", 30)
                collection_title_font = ImageFont.truetype("arial.ttf", 40)
            except Exception:
                preset_font = ImageFont.load_default()
                title_font = ImageFont.load_default()
                collection_title_font = ImageFont.load_default()

            self._cached_fonts = Fonts(preset_font, title_font, collection_title_font)

        return self._cached_fonts

    def generate_presets_images(self, width: int = 1200, height: int = None) -> None:
        """
        Generate a PNG image showing the radio presets in the preset_manager as three arrays
        displayed side by side, with the name and frequency columns in each, and the radio
        name as the title of each.
        
        Args:
            width: Width of the generated image in pixels (default: 1200)
            height: Height of the generated image in pixels (default: automatically calculated)
        """

        if not self.presets_definition or not self.presets_definition.collections:
            return

        # Browse the preset collection and generate an image for each
        for preset_collection in self.presets_definition.collections.values():
            # Get resolved radios
            resolved_radios = preset_collection.get_resolved_radios(self.radios_definition)
            radios_list = list(resolved_radios.items())
            radio_count = len(radios_list)
            
            if radio_count > 0 and preset_collection.used_in_mission:
                # Define background colors for each radio table
                radio_colors = [(255, 0, 0), (0, 128, 0), (255, 165, 0)]  # Red, Green, Orange
                
                # Calculate dimensions based on content
                row_height = 30
                header_height = 55
                margin_between_tables = 30  # Margin between tables
                side_margin = 50  # Margin on sides
                top_margin = 80  # Space for collection title
                bottom_margin = 50  # Margin at bottom
                
                # Compute the highest channel across all radios
                max_channels = 0
                for _, radio in radios_list:
                    for channel in radio.channels.values():
                        if channel.number and channel.number > max_channels:
                            max_channels = channel.number

                # Find the radio with the most channels to determine image height
                image_height = top_margin + header_height + max_channels * row_height + bottom_margin
                image_height = height if height is not None else image_height
                
                # Calculate table widths and positions with margins
                image_width = width
                available_width = image_width - 2 * side_margin - (radio_count - 1) * margin_between_tables
                table_width = available_width // radio_count if radio_count > 0 else 400
                
                # Create image with light yellow background (like old paper)
                image = Image.new('RGB', (image_width, image_height), color=(255, 255, 224))  # Light yellow
                draw = ImageDraw.Draw(image)
                
                fonts: Fonts = self.get_fonts()

                # Draw collection title
                collection_title = preset_collection.title or preset_collection.name
                # Get text dimensions for centering
                title_bbox = draw.textbbox((0, 0), collection_title, font=fonts.collection_title)
                title_width = title_bbox[2] - title_bbox[0]
                title_x = (image_width - title_width) // 2
                draw.text((title_x, 20), collection_title, fill='black', font=fonts.collection_title)

                # Draw each radio as a table
                for i, (_, radio) in enumerate(radios_list):
                    if i >= 3:  # Only draw up to 3 radios
                        break
                        
                    # Calculate table position with margins
                    table_x = side_margin + i * (table_width + margin_between_tables)
                    table_y = top_margin  # Space for collection title
                    
                    # Define column widths
                    column_width_channel = table_width * 0.13
                    column_width_name = table_width * 0.67
                    
                    # Draw table background (optional, for better visibility)
                    table_height = header_height + len(radio.channels) * row_height + 10
                    draw.rectangle([table_x, table_y, table_x + table_width, table_y + table_height], outline='black')
                    
                    # Draw title row with specific background color
                    title_color = radio_colors[i] if i < len(radio_colors) else (200, 200, 200)  # Default gray
                    draw.rectangle([table_x, table_y, table_x + table_width, table_y + header_height], fill=title_color)
                    
                    # Draw radio title (merged columns)
                    radio_title = radio.title or radio.name
                    title_bbox = draw.textbbox((0, 0), radio_title, font=fonts.title)
                    title_width = title_bbox[2] - title_bbox[0]
                    title_x_pos = table_x + (table_width - title_width) // 2
                    title_y_pos = table_y + (header_height - (title_bbox[3] - title_bbox[1])) // 2
                    draw.text((title_x_pos, title_y_pos), radio_title, fill='white', font=fonts.title)
                    
                    # Draw column headers
                    header_y = table_y + header_height
                    draw.rectangle([table_x, header_y, table_x + table_width, header_y + row_height], fill=(200, 200, 200))  # Gray header
                    draw.line([table_x + column_width_channel, header_y, table_x + column_width_channel, header_y + row_height], fill='black')  # Vertical line
                    draw.line([table_x + column_width_channel + column_width_name, header_y, table_x + column_width_channel + column_width_name, header_y + row_height], fill='black')  # Vertical line
                    draw.text((table_x + 10, header_y + 5), "CH", fill='black', font=fonts.preset)
                    draw.text((table_x + column_width_channel + 10, header_y + 5), "Name", fill='black', font=fonts.preset)
                    draw.text((table_x + column_width_channel + column_width_name + 10, header_y + 5), "Freq.", fill='black', font=fonts.preset)
                    draw.line([table_x, header_y + row_height, table_x + table_width, header_y + row_height], fill='black')  # Bottom line
                    
                    # Draw channels with alternating backgrounds
                    channel_list = list(radio.channels.items())
                    for j in range(max_channels):
                        # Skip empty rows if radio has fewer channels
                        channel_index = 0
                        while True:
                            channel_tuple = channel_list[channel_index] if channel_index < len(channel_list) else None
                            channel_index += 1
                            if not channel_tuple or channel_tuple[1].number == j+1:
                                break
                        channel = channel_tuple[1] if channel_tuple else None
                        channel_number = f"{j+1:02d}"
                        channel_name = channel.name if channel is not None else ""
                        channel_frequency = f"{channel.freq:.2f}" if channel is not None else ""

                        row_y = header_y + row_height + j * row_height
                        
                        # Alternate background colors (light gray and white)
                        bg_color = (240, 240, 240) if j % 2 == 0 else (255, 255, 255)  # Light gray and white
                        draw.rectangle([table_x, row_y, table_x + table_width, row_y + row_height], fill=bg_color)
                        
                        # Draw vertical lines between columns
                        draw.line([table_x + column_width_channel, row_y, table_x + column_width_channel, row_y + row_height], fill='black')
                        draw.line([table_x + column_width_channel + column_width_name, row_y, table_x + column_width_channel + column_width_name, row_y + row_height], fill='black')
                        
                        # Draw channel number
                        draw.text((table_x + 10, row_y + 5), channel_number, fill='black', font=fonts.preset)
                        
                        # Draw channel name
                        draw.text((table_x + column_width_channel + 10, row_y + 5), channel_name, fill='black', font=fonts.preset)
                        
                        # Draw frequency
                        draw.text((table_x + column_width_channel + column_width_name + 10, row_y + 5), channel_frequency, fill='black', font=fonts.preset)
                        
                        # Draw horizontal line at bottom of row
                        draw.line([table_x, row_y + row_height, table_x + table_width, row_y + row_height], fill='black')

                # Store the image in the dictionary with the preset collection name as key
                if self.presets_images is None:
                    self.presets_images = {}

                img_buffer = io.BytesIO()
                image.save(img_buffer, format="PNG", optimize=True) # Use PNG with optimization for line art/text
                img_buffer.seek(0)
                self.presets_images[preset_collection.name] = img_buffer
