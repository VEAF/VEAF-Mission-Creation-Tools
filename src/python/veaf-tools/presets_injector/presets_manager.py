"""
Classes for managing radio presets data from YAML files.
"""
from dataclasses import dataclass
from typing import Optional, Union, Dict, Any
import yaml


@dataclass
class RadioChannel:
    """
    Represents a radio channel preset with frequency, name, and modulation.
    """
    freq: float
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
    def from_dict(cls, data: Dict[str, Any]) -> 'RadioChannel':
        """
        Create a RadioChannel instance from a dictionary.
        
        Args:
            data: Dictionary containing channel data
            
        Returns:
            RadioChannel: New instance
            
        Raises:
            ValueError: If frequency is missing from data
        """
        if "freq" not in data:
            raise ValueError("Frequency is mandatory in channel data")
        
        return cls(
            freq=float(data["freq"]),
            name=data.get("name"),
            mod=int(data.get("mod", 0))
        )


@dataclass
class Radio:
    """
    Represents a radio with multiple channels.
    """
    name: str
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
    def from_dict(cls, name: str, data: Dict[str, Any]) -> 'Radio':
        """
        Create a Radio instance from a dictionary.
        
        Args:
            name: The name of the radio
            data: Dictionary containing radio data
            
        Returns:
            Radio: New instance
        """
        if "channels" not in data:
            raise ValueError("Radio data must contain 'channels' key")

        channels = {
            channel_name: RadioChannel.from_dict(channel_data) for channel_name, channel_data in data["channels"].items()
        }
        return cls(name=name, channels=channels)


@dataclass
class PresetCollection:
    """
    Represents a collection of radios (a preset collection).
    """
    name: str
    radios: Dict[str, Radio]
    
    def __post_init__(self):
        """Validate the preset collection data after initialization."""
        if not isinstance(self.name, str):
            raise TypeError("Preset collection name must be a string")
        
        if not isinstance(self.radios, dict):
            raise TypeError("Radios must be a dictionary")
        
        for radio_name, radio in self.radios.items():
            if not isinstance(radio_name, str):
                raise TypeError("Radio names must be strings")
            if not isinstance(radio, Radio):
                raise TypeError(f"Radio '{radio_name}' must be a Radio instance")
    
    def __str__(self) -> str:
        """Return a human-readable string representation of the preset collection."""
        return f"PresetCollection(name='{self.name}', radios={len(self.radios)} radios)"
    
    def add_radio(self, name: str, radio: Radio) -> None:
        """
        Add a radio to the preset collection.
        
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
        Convert the preset collection to a dictionary representation.
        
        Returns:
            dict: Dictionary representation of the preset collection
        """
        return {
            name: radio.to_dict() for name, radio in self.radios.items()
        }
    
    @classmethod
    def from_dict(cls, name: str, data: Dict[str, Any]) -> 'PresetCollection':
        """
        Create a PresetCollection instance from a dictionary.
        
        Args:
            name: The name of the preset collection
            data: Dictionary containing preset collection data
            
        Returns:
            PresetCollection: New instance
        """
        radios = {
            radio_name: Radio.from_dict(radio_name, radio_data)
            for radio_name, radio_data in data.items()
        }
        return cls(name=name, radios=radios)


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
    def from_dict(cls, data: Dict[str, Any]) -> 'PresetsDefinition':
        """
        Create a PresetsDefinition instance from a dictionary.
        
        Args:
            data: Dictionary containing presets definition data
            
        Returns:
            PresetsDefinition: New instance
        """
        collections = {
            collection_name: PresetCollection.from_dict(
                collection_name, collection_data
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
        return self.assignments.get("coalition", {}).get(coalition, {}).get(aircraft_type, {}).get(group_type)
    
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
    presets_definition: Optional[PresetsDefinition] = None
    presets_assignment: Optional[PresetAssignment] = None
    
    def __post_init__(self):
        """Initialize the presets manager."""
        if self.presets_definition is None:
            self.presets_definition = PresetsDefinition(collections={})
        if self.presets_assignment is None:
            self.presets_assignment = PresetAssignment(assignments={})
    
    def __str__(self) -> str:
        """Return a human-readable string representation of the presets manager."""
        collection_count = len(self.presets_definition.collections) if self.presets_definition else 0
        coalition_count = len(self.presets_assignment.assignments) if self.presets_assignment else 0
        return f"PresetsManager(collections={collection_count}, coalitions={coalition_count})"
    
    def load_from_yaml(self, file_path: str) -> None:
        """
        Load presets data from a YAML file.
        
        Args:
            file_path: Path to the YAML file
        """
        try:
            with open(file_path, 'r') as file:
                data = yaml.safe_load(file)

            # Load presets definition
            if "presets_definition" in data:
                self.presets_definition = PresetsDefinition.from_dict(data["presets_definition"])
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