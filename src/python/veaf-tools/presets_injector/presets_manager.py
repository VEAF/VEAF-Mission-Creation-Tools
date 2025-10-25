"""
This module provides classes to manage radio presets.

- ChannelDefinition
  A radio channel definition, composed of information about the channel (name, title etc.) and about the radio (frequencies, modulations)
- Channels collection
  A list of channels that can be used as a source to define a radio
- RadioDefinition
  A set of channels that will end up as a radio in the .miz file
- Radios collection
  A list of radios that can be used to define presets
- PresetDefinition
  A named set of radios defining a preset definition for a specific aircraft or a group of aircrafts
- Preset assignment
  A link between an aircraft (at minimum) or a group of aircrafts, and a preset. The group of aircraft can be defined with its coalition, aircraft type (plane or helo) and unit type
"""

# TODO add modulation

from dataclasses import dataclass
import io
from pathlib import Path
from typing import Any, Optional
from PIL import Image, ImageDraw, ImageFont
from PIL.ImageFont import FreeTypeFont

import yaml

class Channel:
    """
    A radio channel data, containing all the information that will be stored in the DCS .miz file
    Can be either created from a RadioDefinition channel (when data is directly set on a radio channel) or read from a ChannelDefinition object in a ChannelCollection (when the RadioDefinition channel references an alias), or both (RadioDefinition channel sets an alias and overrides values for specific attributes)
    """

    def __init__(self, name_or_number: int|str, freq: float, title: str = None):
        self.freq: float = freq
        self.title: str = title
        
        if isinstance(name_or_number, str):
            if name_or_number.lower().startswith("channel_"):
                self.number: int = int(name_or_number.lower().split('channel_')[-1])
            else:
                self.number: int = int(name_or_number)
        else:
            self.number: int = name_or_number

class ChannelDefinition:
    """
    A radio channel definition, composed of information about the channel (name, title etc.) and about the radio (frequencies, modulations)
    """

    def __init__(self, name: str, title: str = None, misc_data: str = None, collection_name: str = None):
        self.name: str = name
        self.title: str = title
        self.misc_data: str = misc_data
        self.collection_name: str = collection_name
        self.frequencies: dict[str, float] = {}

    def add_freq(self, mode: str, freq: float|str):
        if not mode: raise ValueError("mode is mandatory")
        if not freq: raise ValueError("freq is mandatory")
        f_freq = freq if isinstance(freq, float) else float(freq)
        if not f_freq: raise ValueError("freq should be a float or a str representation of a float")
        self.frequencies[mode] = f_freq

    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> 'ChannelDefinition':
        """
        Create a ChannelDefinition instance from a dictionary.
        
        Args:
            data: Dictionary containing channels definition data
            
        Returns:
            ChannelDefinition: New instance
        """
        title = data.get("title")
        misc_data = data.get("data")
        freqs = data.get("freqs")
        if not freqs: raise ValueError(f"'freqs' is mandatory for ChannelDefinition {name}")
        result = ChannelDefinition(name=name, title=title, misc_data=misc_data)
        for freq_mode, freq_value in freqs.items():
            result.add_freq(mode=freq_mode, freq=freq_value)
        return result

class ChannelCollection:
    """
    A list of channels that can be used as a source to define a radio
    """  
    
    def __init__(self, name: str):
        self.name = name
        self.channel_definitions: dict[str, ChannelDefinition] = {}

    def add_channel_definition(self, channel: ChannelDefinition):
        if not channel: raise ValueError("channel is mandatory")
        if not channel.name: raise ValueError("channel has no 'name' attribute")
        channel.collection_name = self.name
        self.channel_definitions[channel.name] = channel

    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> 'ChannelCollection':
        """
        Create a ChannelCollection instance from a dictionary.
        
        Args:
            data: Dictionary containing channels definition data
            
        Returns:
            ChannelCollection: New instance
        """

        result = ChannelCollection(name=name)
        for item_name in data:
            item = ChannelDefinition.from_dict(name=item_name, data=data[item_name])
            result.add_channel_definition(item)
        return result

class RadioDefinition:
    """
    A set of channels that will end up as a radio in the .miz file
    """

    def __init__(self, name: str, type: str, title: str = None):
        self.name: str = name
        self.type: str = type
        self.title: str = title
        self.channels: list[Channel] = []
        self.collection_name: Optional[str] = None
       
    def add_channel(self, channel: Channel):
        if not channel: raise ValueError("channel is mandatory")
        self.channels.append(channel)

    def to_dict(self) -> dict[str, Any]:
        """
        Convert the radio to a dictionary representation.
        
        Returns:
            dict: Dictionary representation of the radio
        """

        return {
            "channelsNames": {(channel.number): channel.title for channel in self.channels } if any(channel.title for channel in self.channels) else {},
            #"modulations": {
            #    int(channel.name) if channel.name.isdigit() else int(channel.name.split('_')[-1]): channel.mod for channel in self.channels
            #},
            "channels": {
                int(channel.number): channel.freq for channel in self.channels
            }
        }
    
    def get_freq_of_first_channel(self) -> float:
        if self.channels:
            if first_channel := next(iter(self.channels)):
                return first_channel.freq

    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any], channel_collections: dict[str, ChannelCollection]) -> 'RadioDefinition':
        """
        Create a RadioDefinition instance from a dictionary.
        
        Args:
            data: Dictionary containing channels definition data
            channel_collections: used to resolve the channel aliases
            
        Returns:
            RadioDefinition: New instance
        """
        title = data.get("title")
        radio_type = data.get("type")
        channels = data.get("channels")
        if not radio_type: raise ValueError(f"'type' is mandatory for RadioDefinition {name}")
        if not channels: raise ValueError(f"'channels' is mandatory for RadioDefinition {name}")
        result = RadioDefinition(name=name, type=radio_type, title=title)
        for channel_name, channel_data in channels.items():
            if channel_data:
                channel_freq = None
                channel_alias = None
                channel_title = None
                if isinstance(channel_data, str): # shortcut to only set the channel alias
                    channel_alias = channel_data
                elif isinstance(channel_data, int): # shortcut to only set the channel frequency
                    channel_freq = channel_data
                else:
                    channel_title = channel_data.get("title")
                    channel_alias = channel_data.get("channel")
                    channel_freq = channel_data.get("freq")
                channel_definition = None
                if channel_alias:
                    for channel_collection in channel_collections.values():
                        if channel_alias in channel_collection.channel_definitions:
                            channel_definition = channel_collection.channel_definitions[channel_alias]
                            channel_title = channel_definition.title
                            if radio_type not in channel_definition.frequencies:
                                raise ValueError(f"'freq' not defined and 'channel_alias' {channel_alias} in RadioDefinition {name} does not contain any frequency of type {radio_type}")
                            else:
                                channel_freq = channel_definition.frequencies[radio_type]
                            break
                    else:
                        raise ValueError(f"'channel_alias' {channel_alias} in RadioDefinition {name} was not found in any ChannelCollection")
                if not channel_freq:
                    raise ValueError(f"'freq' is mandatory for RadioDefinition {name}")
                result.add_channel(Channel(name_or_number=channel_name, freq=channel_freq, title=channel_title))
        return result
    
class RadioCollection:
    """
    A list of radios that can be used to define presets
    """
    
    def __init__(self, name: str):
        self.name = name
        self.radio_definitions: dict[str, RadioDefinition] = {}

    def add_radio_definition(self, radio: RadioDefinition):
        if not radio: raise ValueError("radio is mandatory")
        if not radio.name: raise ValueError("radio has no 'name' attribute")
        radio.collection_name = self.name
        self.radio_definitions[radio.name] = radio

    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any], channel_collections: dict[str, ChannelCollection]) -> 'RadioCollection':
        """
        Create a RadioDefinition instance from a dictionary.
        
        Args:
            data: Dictionary containing channels definition data
            channel_collections: used to resolve the channel aliases

        Returns:
            RadioDefinition: New instance
        """

        result = RadioCollection(name=name)
        for item_name in data:
            item = RadioDefinition.from_dict(name=item_name, data=data[item_name], channel_collections=channel_collections)
            result.add_radio_definition(item)
        return result

class PresetDefinition:
    """
    A named set of radios defining a preset definition for a specific aircraft or a group of aircrafts
    """

    def __init__(self, name: str, title: str = ""):
        self.name = name
        self.radios: dict[str, RadioDefinition] = {}
        self.used_in_mission: bool = False
        self.collection_name = None
        self.title = title

    def add_radio(self, radio_name: str, radio: RadioDefinition):
        if not radio: raise ValueError("radio_alias is mandatory")
        self.radios[radio_name] = radio

    def to_dict(self) -> dict:
        return {
            int(radio_name) if radio_name.isdigit() else int(radio_name.split('_')[-1]): radio.to_dict() for radio_name, radio in self.radios.items()
        }

    def get_freq_of_first_channel_of_first_radio(self) -> float:
        if self.radios:
            if first_radio := next(iter(self.radios.values())):
                return first_radio.get_freq_of_first_channel()

    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any], radio_collections: dict[str, RadioCollection]) -> 'PresetDefinition':
        """
        Create a PresetDefinition instance from a dictionary.
        
        Args:
            data: Dictionary containing channels definition data
            radio_collections: used to resolve the radio aliases
            
        Returns:
            PresetDefinition: New instance
        """
        radios = data.get("radios")
        if not radios: raise ValueError(f"'radios' is mandatory for PresetDefinition {name}")
        result = PresetDefinition(name=name, title=data.get("title"))
        for radio_name, radio_alias in radios.items():
            for radio_collection in radio_collections.values():
                if radio_alias in radio_collection.radio_definitions:
                    radio_definition = radio_collection.radio_definitions[radio_alias]
                    break
            else:
                raise ValueError(f"'radio_alias' {radio_alias} in class PresetDefinition {name} was not found in any RadioCollection")
            result.add_radio(radio_name, radio_definition)
        return result
   
class PresetCollection:
    """
    A list of presets that can be used to define presets
    """
    
    def __init__(self, name: str):
        self.name = name
        self.preset_definitions: dict[str, PresetDefinition] = {}

    def add_preset_definition(self, preset: PresetDefinition):
        if not preset: raise ValueError("preset is mandatory")
        if not preset.name: raise ValueError("preset has no 'name' attribute")
        preset.collection_name = self.name
        self.preset_definitions[preset.name] = preset
    
    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any], radio_collections: dict[str, RadioCollection]) -> 'PresetCollection':
        """
        Create a PresetDefinition instance from a dictionary.
        
        Args:
            data: Dictionary containing channels definition data
            radio_collections: used to resolve the radio aliases
            
        Returns:
            PresetDefinition: New instance
        """

        result = PresetCollection(name=name)
        for item_name in data:
            item = PresetDefinition.from_dict(name=item_name, data=data[item_name], radio_collections=radio_collections)
            result.add_preset_definition(item)
        return result

@dataclass
class PresetAssignment:
    """
    A link between an aircraft (at minimum) or a group of aircrafts, and a preset. The group of aircraft can be defined with its coalition, aircraft type (plane or helo) and unit type
    """

    preset_definition: PresetDefinition
    coalition: str = "all"
    aircraft_type: str = "all"
    unit_type: str = "all"

class PresetAssignmentCollection:
    """
    A link between an aircraft (at minimum) or a group of aircrafts, and a preset. The group of aircraft can be defined with its coalition, aircraft type (plane or helo) and unit type
    """

    def __init__(self):
        self.preset_assignments_dict: dict[str, dict[str, dict[str, PresetAssignment]]] = {}

    @classmethod
    def from_dict(cls, data: dict[str, Any], presets_collections: dict[str, PresetCollection]) -> 'PresetAssignmentCollection':
        """
        Create a PresetAssignmentCollection instance from a dictionary.
        
        Args:
            data: Dictionary containing channels definition data
            channel_collections: used to resolve the channel aliases
            
        Returns:
            PresetAssignmentCollection: New instance
        """

        result = PresetAssignmentCollection()
        for coalition, coalition_data in data.items():
            for aircraft_type, type_data in coalition_data.items():
                for unit_type, preset_definition_name in type_data.items():
                    if preset_definition_name.lower() == 'none':
                        preset_definition = None
                    else:
                        for preset_collection in presets_collections.values():
                            if preset_definition_name in preset_collection.preset_definitions:
                                preset_definition = preset_collection.preset_definitions[preset_definition_name]
                                break
                        else:
                            raise ValueError(f"preset name {preset_definition_name} in PresetAssignmentCollection was not found in any PresetCollection")
                    preset_assignment = PresetAssignment(coalition=coalition, aircraft_type=aircraft_type, unit_type=unit_type, preset_definition=preset_definition)
                    if not result.preset_assignments_dict.get(coalition, {}):
                        result.preset_assignments_dict[coalition] = {}
                    preset_assignments_coalition_dict = result.preset_assignments_dict.get(coalition, {})
                    if not preset_assignments_coalition_dict.get(aircraft_type, {}):
                        preset_assignments_coalition_dict[aircraft_type] = {}
                    preset_assignments_aircraft_type_dict = preset_assignments_coalition_dict.get(aircraft_type, {})
                    preset_assignments_aircraft_type_dict[unit_type] = preset_assignment
        return result
    
    def get_preset_for(self, coalition: str = "all", aircraft_type: str = "all", unit_type: str = "all") -> PresetAssignment:
        return self.preset_assignments_dict.get(coalition, {}).get(aircraft_type, {}).get(unit_type) or \
               self.preset_assignments_dict.get(coalition, {}).get(aircraft_type, {}).get("all") or \
               self.preset_assignments_dict.get(coalition, {}).get("all", {}).get(unit_type) or \
               self.preset_assignments_dict.get("all", {}).get(aircraft_type, {}).get(unit_type) or \
               self.preset_assignments_dict.get("all", {}).get(aircraft_type, {}).get("all") or \
               self.preset_assignments_dict.get("all", {}).get("all", {}).get(unit_type) or \
               self.preset_assignments_dict.get("all", {}).get("all", {}).get("all")


class PresetsManager:
    """
    The presets manager has functions to manage the presets in DCS
    """

    def __init__(self):
        self.channel_collections: dict[str, ChannelCollection] = {}
        self.radio_collections: dict[str, RadioCollection] = {}
        self.preset_collections: dict[str, PresetCollection] = {}
        self.preset_assignments: PresetAssignmentCollection = PresetAssignmentCollection()
        self.presets_images: dict[str, io.BytesIO] = None
        self._cached_fonts: tuple[FreeTypeFont, FreeTypeFont, FreeTypeFont] = ()

    def read_yaml(self, yaml_path: Path):
        try:
            with open(yaml_path, 'r') as file:
                data = yaml.safe_load(file)

            # Load channel collections
            if "channels_collection" in data:
                collection = data["channels_collection"]
                for name in collection:
                    self.channel_collections[name] = ChannelCollection.from_dict(name=name, data=collection[name])

            # Load radio collections
            if "radios_collection" in data:
                collection = data["radios_collection"]
                for name in collection:
                    self.radio_collections[name] = RadioCollection.from_dict(name=name, data=collection[name], channel_collections=self.channel_collections)

            # Load preset collections
            if "presets_collection" in data:
                collection = data["presets_collection"]
                for name in collection:
                    self.preset_collections[name] = PresetCollection.from_dict(name=name, data=collection[name], radio_collections=self.radio_collections)

            # Load preset assignments
            if "presets_assignments" in data:
                collection = data["presets_assignments"]
                self.preset_assignments = PresetAssignmentCollection.from_dict(data=collection, presets_collections=self.preset_collections)

        except FileNotFoundError as e:
            raise FileNotFoundError(f"YAML file not found: {yaml_path}") from e
        except yaml.YAMLError as e:
            raise ValueError(f"Error parsing YAML file {yaml_path}: {str(e)}") from e
        except Exception as e:
            raise RuntimeError(f"Error loading presets from {yaml_path}: {str(e)}") from e
    
    def write_yaml(self, yaml_path: Path):
        # TODO do this later when implementing the GUI editor
        pass

    def get_radios_for(self, coalition: str, aircraft_type: str, unit_type: str):
        preset_assignment = self.preset_assignments.get_preset_for(coalition=coalition, aircraft_type=aircraft_type, unit_type=unit_type)
        return preset_assignment.preset_definition if preset_assignment else None

    def get_fonts(self) -> tuple[FreeTypeFont, FreeTypeFont, FreeTypeFont]:
        if not self._cached_fonts:
            try:
                preset_font = ImageFont.truetype("arial.ttf", 18)
                title_font = ImageFont.truetype("arial.ttf", 30)
                collection_title_font = ImageFont.truetype("arial.ttf", 40)
            except Exception:
                preset_font = ImageFont.load_default()
                title_font = ImageFont.load_default()
                collection_title_font = ImageFont.load_default()

            self._cached_fonts = (preset_font, title_font, collection_title_font)

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

        # Browse the preset collection and generate an image for each
        for preset_collection in self.preset_collections.values():
            for preset_name, preset_definition in preset_collection.preset_definitions.items():
                radio_count = len(preset_definition.radios)
                
                if radio_count > 0 and preset_definition.used_in_mission:
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
                    for radio in preset_definition.radios.values():
                        for channel in radio.channels:
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
                    
                    fonts: tuple[FreeTypeFont, FreeTypeFont, FreeTypeFont] = self.get_fonts()

                    # Draw collection title
                    # Get text dimensions for centering
                    title_bbox = draw.textbbox((0, 0), preset_definition.title, font=fonts[2])
                    title_width = title_bbox[2] - title_bbox[0]
                    title_x = (image_width - title_width) // 2
                    draw.text((title_x, 20), preset_definition.title, fill='black', font=fonts[2])

                    # Draw each radio as a table
                    for i, radio in enumerate(preset_definition.radios.values()):
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
                        title_bbox = draw.textbbox((0, 0), radio_title, font=fonts[1])
                        title_width = title_bbox[2] - title_bbox[0]
                        title_x_pos = table_x + (table_width - title_width) // 2
                        title_y_pos = table_y + (header_height - (title_bbox[3] - title_bbox[1])) // 2
                        draw.text((title_x_pos, title_y_pos), radio_title, fill='white', font=fonts[1])
                        
                        # Draw column headers
                        header_y = table_y + header_height
                        draw.rectangle([table_x, header_y, table_x + table_width, header_y + row_height], fill=(200, 200, 200))  # Gray header
                        draw.line([table_x + column_width_channel, header_y, table_x + column_width_channel, header_y + row_height], fill='black')  # Vertical line
                        draw.line([table_x + column_width_channel + column_width_name, header_y, table_x + column_width_channel + column_width_name, header_y + row_height], fill='black')  # Vertical line
                        draw.text((table_x + 10, header_y + 5), "CH", fill='black', font=fonts[0])
                        draw.text((table_x + column_width_channel + 10, header_y + 5), "Name", fill='black', font=fonts[0])
                        draw.text((table_x + column_width_channel + column_width_name + 10, header_y + 5), "Freq.", fill='black', font=fonts[0])
                        draw.line([table_x, header_y + row_height, table_x + table_width, header_y + row_height], fill='black')  # Bottom line
                        
                        # Draw channels with alternating backgrounds
                        for j in range(max_channels):
                            # Skip empty rows if radio has fewer channels
                            channel_index = 0
                            while True:
                                channel = radio.channels[channel_index] if channel_index < len(radio.channels) else None
                                channel_index += 1
                                if not channel or channel.number == j+1:
                                    break
                            channel_number = f"{j+1:02d}"
                            channel_name = channel.title if channel is not None else ""
                            channel_frequency = f"{channel.freq:.2f}" if channel is not None else ""

                            row_y = header_y + row_height + j * row_height
                            
                            # Alternate background colors (light gray and white)
                            bg_color = (240, 240, 240) if j % 2 == 0 else (255, 255, 255)  # Light gray and white
                            draw.rectangle([table_x, row_y, table_x + table_width, row_y + row_height], fill=bg_color)
                            
                            # Draw vertical lines between columns
                            draw.line([table_x + column_width_channel, row_y, table_x + column_width_channel, row_y + row_height], fill='black')
                            draw.line([table_x + column_width_channel + column_width_name, row_y, table_x + column_width_channel + column_width_name, row_y + row_height], fill='black')
                            
                            # Draw channel number
                            draw.text((table_x + 10, row_y + 5), channel_number, fill='black', font=fonts[0])
                            
                            # Draw channel name
                            draw.text((table_x + column_width_channel + 10, row_y + 5), channel_name or "", fill='black', font=fonts[0])
                            
                            # Draw frequency
                            draw.text((table_x + column_width_channel + column_width_name + 10, row_y + 5), channel_frequency, fill='black', font=fonts[0])
                            
                            # Draw horizontal line at bottom of row
                            draw.line([table_x, row_y + row_height, table_x + table_width, row_y + row_height], fill='black')

                    # Store the image in the dictionary with the preset collection name as key
                    if self.presets_images is None:
                        self.presets_images = {}

                    img_buffer = io.BytesIO()
                    image.save(img_buffer, format="PNG", optimize=True) # Use PNG with optimization for line art/text
                    img_buffer.seek(0)
                    self.presets_images[preset_name] = img_buffer
