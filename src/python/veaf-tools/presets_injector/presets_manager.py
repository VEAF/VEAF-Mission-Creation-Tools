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
from veaf_libs.logger import logger
from veaf_libs.progress import spinner_context, progress_context

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
        if not mode: logger.error(message="mode is mandatory", exception_type=ValueError)
        if not freq: logger.error(message="freq is mandatory", exception_type=ValueError)
        f_freq = freq if isinstance(freq, float) else float(freq)
        if not f_freq: logger.error(message="freq should be a float or a str representation of a float", exception_type=ValueError)
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
        if not freqs: logger.error(message=f"'freqs' is mandatory for ChannelDefinition {name}", exception_type=ValueError)
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
        if not channel: logger.error(message="channel is mandatory", exception_type=ValueError)
        if not channel.name: logger.error(message="channel has no 'name' attribute", exception_type=ValueError)
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

    def __init__(self, name: str, radio_type: str, title: str = None):
        self.name: str = name
        self.radio_type: str = radio_type
        self.title: str = title
        self.channels: list[Channel] = []
        self.collection_name: Optional[str] = None
       
    def add_channel(self, channel: Channel):
        if not channel: logger.error(message="channel is mandatory", exception_type=ValueError)
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

    def add_channel_from_dict(self, channel_name: str, channel_data: dict[str, Any], channel_collections: dict[str, ChannelCollection]):
        if not channel_data:
            return
        channel_freq = None
        channel_alias = None
        channel_title = None
        if isinstance(channel_data, str): # shortcut to only set the channel alias
            channel_alias = channel_data
        elif isinstance(channel_data, float|int): # shortcut to only set the channel frequency
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
                    if self.radio_type not in channel_definition.frequencies:
                        logger.error(message=f"'freq' not defined and 'channel_alias' {channel_alias} in RadioDefinition {self.name} does not contain any frequency of type {self.radio_type}", exception_type=ValueError)
                    else:
                        channel_freq = channel_definition.frequencies[self.radio_type]
                    break
            else:
                logger.error(message=f"'channel_alias' {channel_alias} in RadioDefinition {self.name} was not found in any ChannelCollection", exception_type=ValueError)
        if not channel_freq:
            logger.error(message=f"'freq' is mandatory for RadioDefinition {self.name}", exception_type=ValueError)
        self.add_channel(Channel(name_or_number=channel_name, freq=channel_freq, title=channel_title))

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
        if not radio_type: logger.error(message=f"'type' is mandatory for RadioDefinition {name}", exception_type=ValueError)
        if not channels: logger.error(message=f"'channels' is mandatory for RadioDefinition {name}", exception_type=ValueError)
        result = RadioDefinition(name=name, radio_type=radio_type, title=title)
        for channel_name, channel_data in channels.items():
            result.add_channel_from_dict(channel_name, channel_data, channel_collections)
        return result
    
class RadioCollection:
    """
    A list of radios that can be used to define presets
    """
    
    def __init__(self, name: str):
        self.name = name
        self.radio_definitions: dict[str, RadioDefinition] = {}

    def add_radio_definition(self, radio: RadioDefinition):
        if not radio: logger.error(message="radio is mandatory", exception_type=ValueError)
        if not radio.name: logger.error(message="radio has no 'name' attribute", exception_type=ValueError)
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

    def add_radio(self, radio: RadioDefinition):
        if not radio: logger.error(message="radio_alias is mandatory", exception_type=ValueError)
        self.radios[radio.name] = radio

    def to_dict(self) -> dict:
        return {
            radio_number+1: radio.to_dict() for radio_number, radio in enumerate(self.radios.values())
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
        if not radios: logger.error(message=f"'radios' is mandatory for PresetDefinition {name}", exception_type=ValueError)
        result = PresetDefinition(name=name, title=data.get("title"))
        for radio_name, radio_alias in radios.items():
            for radio_collection in radio_collections.values():
                if radio_alias in radio_collection.radio_definitions:
                    radio_definition = radio_collection.radio_definitions[radio_alias]
                    break
            else:
                logger.error(message=f"'radio_alias' {radio_alias} in class PresetDefinition {name} was not found in any RadioCollection", exception_type=ValueError)
            result.add_radio(radio_definition)
        return result

PresetDefinition.EMPTY = PresetDefinition("empty")

class PresetCollection:
    """
    A list of presets that can be used to define presets
    """
    
    def __init__(self, name: str):
        self.name = name
        self.preset_definitions: dict[str, PresetDefinition] = {}

    def add_preset_definition(self, preset: PresetDefinition):
        if not preset: logger.error(message="preset is mandatory", exception_type=ValueError)
        if not preset.name: logger.error(message="preset has no 'name' attribute", exception_type=ValueError)
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
                    elif preset_definition_name.lower() == 'empty':
                        preset_definition = PresetDefinition.EMPTY
                    else:
                        for preset_collection in presets_collections.values():
                            if preset_definition_name in preset_collection.preset_definitions:
                                preset_definition = preset_collection.preset_definitions[preset_definition_name]
                                break
                        else:
                            logger.error(message=f"preset name {preset_definition_name} in PresetAssignmentCollection was not found in any PresetCollection", exception_type=ValueError)
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
            logger.error(message=f"YAML file not found: {yaml_path}", exception_type=FileNotFoundError)
        except yaml.YAMLError as e:
            logger.error(message=f"Error parsing YAML file {yaml_path}: {str(e)}", exception_type=ValueError)
        except Exception as e:
            logger.error(message=f"Error loading presets from {yaml_path}: {str(e)}", exception_type=RuntimeError)
    
    def write_yaml(self, yaml_path: Path):
        # TODO do this later when implementing the GUI editor
        pass

    def get_radios_for(self, coalition: str, aircraft_type: str, unit_type: str):
        preset_assignment = self.preset_assignments.get_preset_for(coalition=coalition, aircraft_type=aircraft_type, unit_type=unit_type)
        return preset_assignment.preset_definition if preset_assignment else None


    def generate_presets_images(self, width: int = 1200, height: int = None):
        generator = RadioPresetsImageGenerator(self.preset_collections, width=width, height=height)
        self.presets_images = generator.generate_presets_images()

class RadioPresetsImageGenerator:

    def __init__(self, preset_collections: dict[str, PresetCollection], width: int = 1200, height: int = None):
        self.width = width
        self.height = height
        self.preset_collections = preset_collections
        self._cached_fonts: tuple[FreeTypeFont, FreeTypeFont, FreeTypeFont] | None = None

    def get_fonts(self) -> tuple[FreeTypeFont, FreeTypeFont, FreeTypeFont]:
        if not self._cached_fonts:
            try:
                ARIAL = "arial.ttf"
                preset_font = ImageFont.truetype(ARIAL, 18)
                title_font = ImageFont.truetype(ARIAL, 30)
                collection_title_font = ImageFont.truetype(ARIAL, 40)
            except Exception:
                preset_font = ImageFont.load_default()
                title_font = ImageFont.load_default()
                collection_title_font = ImageFont.load_default()

            self._cached_fonts = (preset_font, title_font, collection_title_font)

        return self._cached_fonts

    def get_preset_font(self) -> FreeTypeFont:
        return self.get_fonts()[0]

    def get_title_font(self) -> FreeTypeFont:
        return self.get_fonts()[1]

    def get_collection_title_font(self) -> FreeTypeFont:
        return self.get_fonts()[2]

    def draw_channels_in_preset_image(self, radio_definition: RadioDefinition):
        # Draw channels with alternating backgrounds
        for j in range(self.max_channels):
            # Skip empty rows if radio has fewer channels
            channel_index = 0
            while True:
                channel = radio_definition.channels[channel_index] if channel_index < len(radio_definition.channels) else None
                channel_index += 1
                if not channel or channel.number == j+1:
                    break
            channel_number = f"{j+1:02d}"
            channel_name = channel.title if channel is not None else ""
            channel_frequency = f"{channel.freq:.2f}" if channel is not None else ""

            row_y = self.header_y + self.row_height + j * self.row_height
            
            # Alternate background colors (light gray and white)
            bg_color = (240, 240, 240) if j % 2 == 0 else (255, 255, 255)  # Light gray and white
            self.draw.rectangle([self.table_x, row_y, self.table_x + self.table_width, row_y + self.row_height], fill=bg_color)
            
            # Draw vertical lines between columns
            self.draw.line([self.table_x + self.column_width_channel, row_y, self.table_x + self.column_width_channel, row_y + self.row_height], fill='black')
            self.draw.line([self.table_x + self.column_width_channel + self.column_width_name, row_y, self.table_x + self.column_width_channel + self.column_width_name, row_y + self.row_height], fill='black')
            
            # Draw channel number
            self.draw.text((self.table_x + 10, row_y + 5), channel_number, fill='black', font=self.get_preset_font())
            
            # Draw channel name
            self.draw.text((self.table_x + self.column_width_channel + 10, row_y + 5), channel_name or "", fill='black', font=self.get_preset_font())
            
            # Draw frequency
            self.draw.text((self.table_x + self.column_width_channel + self.column_width_name + 10, row_y + 5), channel_frequency, fill='black', font=self.get_preset_font())
            
            # Draw horizontal line at bottom of row
            self.draw.line([self.table_x, row_y + self.row_height, self.table_x + self.table_width, row_y + self.row_height], fill='black')

    def draw_radios_in_preset_image(self, preset_definition: PresetDefinition):
        # Draw each radio as a table
        for i, radio in enumerate(preset_definition.radios.values()):
            if i >= 3:  # Only draw up to 3 radios
                break
                
            # Calculate table position with margins
            self.table_x = self.side_margin + i * (self.table_width + self.margin_between_tables)
            table_y = self.top_margin  # Space for collection title
            
            # Define column widths
            self.column_width_channel = self.table_width * 0.13
            self.column_width_name = self.table_width * 0.67
            
            # Draw table background (optional, for better visibility)
            table_height = self.header_height + len(radio.channels) * self.row_height + 10
            self.draw.rectangle([self.table_x, table_y, self.table_x + self.table_width, table_y + table_height], outline='black')
            
            # Draw title row with specific background color
            title_color = self.radio_colors[i] if i < len(self.radio_colors) else (200, 200, 200)  # Default gray
            self.draw.rectangle([self.table_x, table_y, self.table_x + self.table_width, table_y + self.header_height], fill=title_color)
            
            # Draw radio title (merged columns)
            radio_title = radio.title or radio.name
            title_bbox = self.draw.textbbox((0, 0), radio_title, font=self.get_title_font())
            title_width = title_bbox[2] - title_bbox[0]
            title_x_pos = self.table_x + (self.table_width - title_width) // 2
            title_y_pos = table_y + (self.header_height - (title_bbox[3] - title_bbox[1])) // 2
            self.draw.text((title_x_pos, title_y_pos), radio_title, fill='white', font=self.get_title_font())
            
            # Draw column headers
            self.header_y = table_y + self.header_height
            self.draw.rectangle([self.table_x, self.header_y, self.table_x + self.table_width, self.header_y + self.row_height], fill=(200, 200, 200))  # Gray header
            self.draw.line([self.table_x + self.column_width_channel, self.header_y, self.table_x + self.column_width_channel, self.header_y + self.row_height], fill='black')  # Vertical line
            self.draw.line([self.table_x + self.column_width_channel + self.column_width_name, self.header_y, self.table_x + self.column_width_channel + self.column_width_name, self.header_y + self.row_height], fill='black')  # Vertical line
            self.draw.text((self.table_x + 10, self.header_y + 5), "CH", fill='black', font=self.get_preset_font())
            self.draw.text((self.table_x + self.column_width_channel + 10, self.header_y + 5), "Name", fill='black', font=self.get_preset_font())
            self.draw.text((self.table_x + self.column_width_channel + self.column_width_name + 10, self.header_y + 5), "Freq.", fill='black', font=self.get_preset_font())
            self.draw.line([self.table_x, self.header_y + self.row_height, self.table_x + self.table_width, self.header_y + self.row_height], fill='black')  # Bottom line

            # Draw channels
            self.draw_channels_in_preset_image(radio_definition=radio)

    def draw_preset_image(self, preset_definition: PresetDefinition):
        # Define background colors for each radio table
        self.radio_colors = [(255, 0, 0), (0, 128, 0), (255, 165, 0)]  # Red, Green, Orange
        
        # Calculate dimensions based on content
        self.row_height = 30
        self.header_height = 55
        self.margin_between_tables = 30  # Margin between tables
        self.side_margin = 50  # Margin on sides
        self.top_margin = 80  # Space for collection title
        bottom_margin = 50  # Margin at bottom
        
        # Compute the highest channel across all radios
        self.max_channels = 0
        for radio in preset_definition.radios.values():
            for channel in radio.channels:
                if channel.number and channel.number > self.max_channels:
                    self.max_channels = channel.number

        # Find the radio with the most channels to determine image height
        image_height = self.top_margin + self.header_height + self.max_channels * self.row_height + bottom_margin
        image_height = self.height if self.height is not None else image_height
        
        # Calculate table widths and positions with margins
        image_width = self.width
        available_width = image_width - 2 * self.side_margin - (self.radio_count - 1) * self.margin_between_tables
        self.table_width = available_width // self.radio_count if self.radio_count > 0 else 400
        
        # Create image with light yellow background (like old paper)
        self.image = Image.new('RGB', (image_width, image_height), color=(255, 255, 224))  # Light yellow
        self.draw = ImageDraw.Draw(self.image)
        
        # Draw collection title
        # Get text dimensions for centering
        title_bbox = self.draw.textbbox((0, 0), preset_definition.title, font=self.get_collection_title_font())
        title_width = title_bbox[2] - title_bbox[0]
        title_x = (image_width - title_width) // 2
        self.draw.text((title_x, 20), preset_definition.title, fill='black', font=self.get_collection_title_font())

    def generate_presets_images(self) -> dict[str, io.BytesIO]:
        """
        Generate a PNG image showing the radio presets in the preset_manager as three arrays
        displayed side by side, with the name and frequency columns in each, and the radio
        name as the title of each.
        
        Args:
            width: Width of the generated image in pixels (default: 1200)
            height: Height of the generated image in pixels (default: automatically calculated)
        """
        
        presets_images = {}

        # Browse the preset collection and generate an image for each
        for preset_collection in self.preset_collections.values():
            for preset_name, preset_definition in preset_collection.preset_definitions.items():
                self.radio_count = len(preset_definition.radios)
                
                if self.radio_count > 0 and preset_definition.used_in_mission:

                    self.draw_preset_image(preset_definition)

                    self.draw_radios_in_preset_image(preset_definition)

                    # Store the image in the dictionary with the preset collection name as key
                    img_buffer = io.BytesIO()
                    self.image.save(img_buffer, format="PNG", optimize=True) # Use PNG with optimization for line art/text
                    img_buffer.seek(0)
                    presets_images[preset_name] = img_buffer
        
        return presets_images