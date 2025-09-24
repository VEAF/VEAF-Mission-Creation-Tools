"""
Classes for managing radio presets data from YAML files.
"""
from dataclasses import dataclass
import io
from typing import Optional, Dict, Any, List
import yaml
from PIL import Image, ImageDraw, ImageFont


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
    def from_dict(cls, channel_name, data: Dict[str, Any]) -> 'RadioChannel':
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
            name=data.get("name", channel_name.replace("channel_", "Channel ")),
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
    def from_dict(cls, name: str, data: Dict[str, Any]) -> 'Radio':
        """
        Create a Radio instance from a dictionary.
        
        Args:
            name: The name of the radio
            data: Dictionary containing radio data
            
        Returns:
            Radio: New instance
        """
        title = data.get("title", "Unnamed Radio")
        if "channels" not in data:
            raise ValueError("Radio data must contain 'channels' key")

        channels = {
            channel_name: RadioChannel.from_dict(channel_name, channel_data) for channel_name, channel_data in data["channels"].items()
        }
        return cls(name=name, title=title, channels=channels)


@dataclass
class PresetCollection:
    """
    Represents a collection of radios (a preset collection).
    """
    name: str
    title: str
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
        title = data.get("title", "Unnamed preset collection")
        radios = {
            radio_name: Radio.from_dict(radio_name, radio_data)
            for radio_name, radio_data in data["radios"].items()
        }
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
        return self.assignments.get("coalitions", {}).get(coalition, {}).get(aircraft_type, {}).get(group_type)
    
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
    presets_images: Optional[Dict[str, io.BytesIO]] = None
    
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

            # Generate images for presets
            self.generate_presets_images(width=1200, height=None)

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
            # Convert radios to a list to maintain order and allow indexing
            radios_list = list(preset_collection.radios.items())
            radio_count = len(radios_list)
            
            if radio_count > 0:
                # Define background colors for each radio table
                radio_colors = [(255, 0, 0), (0, 128, 0), (255, 165, 0)]  # Red, Green, Orange
                
                # Calculate dimensions based on content
                row_height = 30
                header_height = 55
                margin_between_tables = 30  # Margin between tables
                side_margin = 50  # Margin on sides
                top_margin = 80  # Space for collection title
                bottom_margin = 50  # Margin at bottom
                
                # Find the radio with the most channels to determine image height
                max_channels = max(len(radio.channels) for _, radio in radios_list)
                image_height = top_margin + header_height + max_channels * row_height + bottom_margin
                image_height = height if height is not None else image_height
                
                # Calculate table widths and positions with margins
                image_width = width
                available_width = image_width - 2 * side_margin - (radio_count - 1) * margin_between_tables
                table_width = available_width // radio_count if radio_count > 0 else 400
                
                # Create image with light yellow background (like old paper)
                image = Image.new('RGB', (image_width, image_height), color=(255, 255, 224))  # Light yellow
                draw = ImageDraw.Draw(image)

                # Try to use a better font, fallback to default if not available
                try:
                    font = ImageFont.truetype("arial.ttf", 18)
                    title_font = ImageFont.truetype("arial.ttf", 30)
                    collection_title_font = ImageFont.truetype("arial.ttf", 40)
                except Exception:
                    font = ImageFont.load_default()
                    title_font = ImageFont.load_default()
                    collection_title_font = ImageFont.load_default()

                # Draw collection title
                collection_title = preset_collection.title or preset_collection.name
                # Get text dimensions for centering
                title_bbox = draw.textbbox((0, 0), collection_title, font=collection_title_font)
                title_width = title_bbox[2] - title_bbox[0]
                title_x = (image_width - title_width) // 2
                draw.text((title_x, 20), collection_title, fill='black', font=collection_title_font)

                # Draw each radio as a table
                for i, (_, radio) in enumerate(radios_list):
                    if i >= 3:  # Only draw up to 3 radios
                        break
                        
                    # Calculate table position with margins
                    table_x = side_margin + i * (table_width + margin_between_tables)
                    table_y = top_margin  # Space for collection title
                    
                    # Define column widths
                    column_width_name = table_width * 0.6
                    column_width_freq = table_width * 0.4
                    
                    # Draw table background (optional, for better visibility)
                    table_height = header_height + len(radio.channels) * row_height + 10
                    draw.rectangle([table_x, table_y, table_x + table_width, table_y + table_height], outline='black')
                    
                    # Draw title row with specific background color
                    title_color = radio_colors[i] if i < len(radio_colors) else (200, 200, 200)  # Default gray
                    draw.rectangle([table_x, table_y, table_x + table_width, table_y + header_height], fill=title_color)
                    
                    # Draw radio title (merged columns)
                    radio_title = radio.title or radio.name
                    title_bbox = draw.textbbox((0, 0), radio_title, font=title_font)
                    title_width = title_bbox[2] - title_bbox[0]
                    title_x_pos = table_x + (table_width - title_width) // 2
                    title_y_pos = table_y + (header_height - (title_bbox[3] - title_bbox[1])) // 2
                    draw.text((title_x_pos, title_y_pos), radio_title, fill='white', font=title_font)
                    
                    # Draw column headers
                    header_y = table_y + header_height
                    draw.rectangle([table_x, header_y, table_x + table_width, header_y + row_height], fill=(200, 200, 200))  # Gray header
                    draw.line([table_x + column_width_name, header_y, table_x + column_width_name, header_y + row_height], fill='black')  # Vertical line
                    draw.text((table_x + 10, header_y + 5), "Name", fill='black', font=font)
                    draw.text((table_x + column_width_name + 10, header_y + 5), "Frequency", fill='black', font=font)
                    draw.line([table_x, header_y + row_height, table_x + table_width, header_y + row_height], fill='black')  # Bottom line
                    
                    # Draw channels with alternating backgrounds
                    channel_list = list(radio.channels.items())
                    for j, (_, channel) in enumerate(channel_list):
                        row_y = header_y + row_height + j * row_height
                        
                        # Alternate background colors (light gray and white)
                        bg_color = (240, 240, 240) if j % 2 == 0 else (255, 255, 255)  # Light gray and white
                        draw.rectangle([table_x, row_y, table_x + table_width, row_y + row_height], fill=bg_color)
                        
                        # Draw vertical line between columns
                        draw.line([table_x + column_width_name, row_y, table_x + column_width_name, row_y + row_height], fill='black')
                        
                        # Draw channel name
                        name_text = channel.name or ""
                        draw.text((table_x + 10, row_y + 5), name_text, fill='black', font=font)
                        
                        # Draw frequency
                        freq_text = f"{channel.freq:.3f}"
                        draw.text((table_x + column_width_name + 10, row_y + 5), freq_text, fill='black', font=font)
                        
                        # Draw horizontal line at bottom of row
                        draw.line([table_x, row_y + row_height, table_x + table_width, row_y + row_height], fill='black')

                # Store the image in the dictionary with the preset collection name as key
                if self.presets_images is None:
                    self.presets_images = {}

                img_buffer = io.BytesIO()
                image.save(img_buffer, format='PNG')
                img_buffer.seek(0)
                self.presets_images[preset_collection.name] = img_buffer
