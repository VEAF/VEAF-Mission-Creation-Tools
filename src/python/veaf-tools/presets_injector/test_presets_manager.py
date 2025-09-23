"""
Unit tests for the presets_manager module.
"""
import unittest
import tempfile
import os
from presets_manager import (
    RadioChannel, Radio, PresetCollection, 
    PresetsDefinition, PresetAssignment, PresetsManager
)


class TestRadioChannel(unittest.TestCase):
    """Test cases for the RadioChannel class."""
    
    def test_create_radio_channel(self):
        """Test creating a RadioChannel instance."""
        channel = RadioChannel(freq=243.0, name="Guard", mod=0)
        self.assertEqual(channel.freq, 243.0)
        self.assertEqual(channel.name, "Guard")
        self.assertEqual(channel.mod, 0)
    
    def test_create_radio_channel_with_defaults(self):
        """Test creating a RadioChannel with default values."""
        channel = RadioChannel(freq=243.0)
        self.assertEqual(channel.freq, 243.0)
        self.assertIsNone(channel.name)
        self.assertEqual(channel.mod, 0)
    
    def test_radio_channel_validation(self):
        """Test RadioChannel validation."""
        # Test missing frequency
        with self.assertRaises(ValueError):
            RadioChannel(freq=None)
        
        # Test invalid frequency range
        with self.assertRaises(ValueError):
            RadioChannel(freq=-1.0)
        
        with self.assertRaises(ValueError):
            RadioChannel(freq=100001.0)
        
        # Test invalid modulation range
        with self.assertRaises(ValueError):
            RadioChannel(freq=243.0, mod=-1)
        
        with self.assertRaises(ValueError):
            RadioChannel(freq=243.0, mod=4)
        
        # Test invalid name type
        with self.assertRaises(TypeError):
            RadioChannel(freq=243.0, name=123)
    
    def test_radio_channel_to_dict(self):
        """Test converting RadioChannel to dictionary."""
        channel = RadioChannel(freq=243.0, name="Guard", mod=0)
        data = channel.to_dict()
        self.assertEqual(data, {"freq": 243.0, "name": "Guard", "mod": 0})
        
        # Test with defaults
        channel = RadioChannel(freq=243.0)
        data = channel.to_dict()
        self.assertEqual(data, {"freq": 243.0})
    
    def test_radio_channel_from_dict(self):
        """Test creating RadioChannel from dictionary."""
        data = {"freq": 243.0, "name": "Guard", "mod": 0}
        channel = RadioChannel.from_dict(data)
        self.assertEqual(channel.freq, 243.0)
        self.assertEqual(channel.name, "Guard")
        self.assertEqual(channel.mod, 0)
        
        # Test missing frequency
        with self.assertRaises(ValueError):
            RadioChannel.from_dict({"name": "Guard"})


class TestRadio(unittest.TestCase):
    """Test cases for the Radio class."""
    
    def test_create_radio(self):
        """Test creating a Radio instance."""
        channels = {
            "channel_01": RadioChannel(freq=243.0, name="Guard"),
            "channel_02": RadioChannel(freq=260.0, name="Batumi / 16X")
        }
        radio = Radio(name="radio_1", channels=channels)
        self.assertEqual(radio.name, "radio_1")
        self.assertEqual(len(radio.channels), 2)
    
    def test_radio_validation(self):
        """Test Radio validation."""
        # Test invalid name type
        with self.assertRaises(TypeError):
            Radio(name=123, channels={})
        
        # Test invalid channels type
        with self.assertRaises(TypeError):
            Radio(name="radio_1", channels=[])
        
        # Test invalid channel name type
        with self.assertRaises(TypeError):
            Radio(name="radio_1", channels={123: RadioChannel(freq=243.0)})
        
        # Test invalid channel type
        with self.assertRaises(TypeError):
            Radio(name="radio_1", channels={"channel_01": "invalid"})
    
    def test_radio_add_channel(self):
        """Test adding a channel to a Radio."""
        radio = Radio(name="radio_1", channels={})
        channel = RadioChannel(freq=243.0, name="Guard")
        radio.add_channel("channel_01", channel)
        self.assertEqual(len(radio.channels), 1)
        self.assertEqual(radio.get_channel("channel_01"), channel)
        
        # Test invalid channel name type
        with self.assertRaises(TypeError):
            radio.add_channel(123, channel)
        
        # Test invalid channel type
        with self.assertRaises(TypeError):
            radio.add_channel("channel_01", "invalid")
    
    def test_radio_remove_channel(self):
        """Test removing a channel from a Radio."""
        channel = RadioChannel(freq=243.0, name="Guard")
        radio = Radio(name="radio_1", channels={"channel_01": channel})
        self.assertTrue(radio.remove_channel("channel_01"))
        self.assertEqual(len(radio.channels), 0)
        self.assertFalse(radio.remove_channel("channel_01"))


class TestPresetCollection(unittest.TestCase):
    """Test cases for the PresetCollection class."""
    
    def test_create_preset_collection(self):
        """Test creating a PresetCollection instance."""
        channels = {
            "channel_01": RadioChannel(freq=243.0, name="Guard"),
            "channel_02": RadioChannel(freq=260.0, name="Batumi / 16X")
        }
        radio = Radio(name="radio_1", channels=channels)
        collection = PresetCollection(name="modern_blue", radios={"radio_1": radio})
        self.assertEqual(collection.name, "modern_blue")
        self.assertEqual(len(collection.radios), 1)
    
    def test_preset_collection_add_radio(self):
        """Test adding a radio to a PresetCollection."""
        collection = PresetCollection(name="modern_blue", radios={})
        channels = {
            "channel_01": RadioChannel(freq=243.0, name="Guard")
        }
        radio = Radio(name="radio_1", channels=channels)
        collection.add_radio("radio_1", radio)
        self.assertEqual(len(collection.radios), 1)
        self.assertEqual(collection.get_radio("radio_1"), radio)


class TestPresetsDefinition(unittest.TestCase):
    """Test cases for the PresetsDefinition class."""
    
    def test_create_presets_definition(self):
        """Test creating a PresetsDefinition instance."""
        channels = {
            "channel_01": RadioChannel(freq=243.0, name="Guard")
        }
        radio = Radio(name="radio_1", channels=channels)
        collection = PresetCollection(name="modern_blue", radios={"radio_1": radio})
        presets_def = PresetsDefinition(collections={"modern_blue": collection})
        self.assertEqual(len(presets_def.collections), 1)
        self.assertEqual(presets_def.get_collection("modern_blue"), collection)


class TestPresetAssignment(unittest.TestCase):
    """Test cases for the PresetAssignment class."""
    
    def test_create_preset_assignment(self):
        """Test creating a PresetAssignment instance."""
        assignments = {
            "blue": {
                "airplanes": {
                    "all": "modern_blue"
                }
            }
        }
        preset_assignment = PresetAssignment(assignments=assignments)
        self.assertEqual(len(preset_assignment.assignments), 1)
        self.assertEqual(preset_assignment.get_assignment("blue", "airplanes", "all"), "modern_blue")
    
    def test_preset_assignment_set_get(self):
        """Test setting and getting preset assignments."""
        preset_assignment = PresetAssignment(assignments={})
        preset_assignment.set_assignment("blue", "airplanes", "all", "modern_blue")
        self.assertEqual(preset_assignment.get_assignment("blue", "airplanes", "all"), "modern_blue")
        self.assertIsNone(preset_assignment.get_assignment("red", "airplanes", "all"))


class TestPresetsManager(unittest.TestCase):
    """Test cases for the PresetsManager class."""
    
    def setUp(self):
        """Set up test fixtures."""
        # Create a temporary YAML file for testing
        self.temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False)
        self.temp_file.write("""
presets_definition:
  modern_blue:
    radio_1:
      channels:
        channel_01:
          freq: 243.0
          name: Guard
        channel_02:
          freq: 260.0
          name: Batumi / 16X

presets_assignments:
  coalition:
    blue:
      airplanes:
        all: modern_blue
""")
        self.temp_file.close()
    
    def tearDown(self):
        """Tear down test fixtures."""
        os.unlink(self.temp_file.name)
    
    def test_create_presets_manager(self):
        """Test creating a PresetsManager instance."""
        manager = PresetsManager()
        self.assertIsInstance(manager.presets_definition, PresetsDefinition)
        self.assertIsInstance(manager.presets_assignment, PresetAssignment)
    
    def test_load_from_yaml(self):
        """Test loading presets from a YAML file."""
        manager = PresetsManager()
        manager.load_from_yaml(self.temp_file.name)
        
        # Check that the data was loaded correctly
        collection = manager.get_preset_collection("modern_blue")
        self.assertIsNotNone(collection)
        self.assertEqual(collection.name, "modern_blue")
        
        radio = collection.get_radio("radio_1")
        self.assertIsNotNone(radio)
        self.assertEqual(radio.name, "radio_1")
        
        channel = radio.get_channel("channel_01")
        self.assertIsNotNone(channel)
        self.assertEqual(channel.freq, 243.0)
        self.assertEqual(channel.name, "Guard")
        
        assignment = manager.get_preset_assignment("blue", "airplanes", "all")
        self.assertEqual(assignment, "modern_blue")
    
    def test_save_to_yaml(self):
        """Test saving presets to a YAML file."""
        # Create a PresetsManager with some data
        channels = {
            "channel_01": RadioChannel(freq=243.0, name="Guard")
        }
        radio = Radio(name="radio_1", channels=channels)
        collection = PresetCollection(name="modern_blue", radios={"radio_1": radio})
        presets_def = PresetsDefinition(collections={"modern_blue": collection})
        
        assignments = {
            "blue": {
                "airplanes": {
                    "all": "modern_blue"
                }
            }
        }
        preset_assignment = PresetAssignment(assignments=assignments)
        
        manager = PresetsManager(
            presets_definition=presets_def,
            presets_assignment=preset_assignment
        )
        
        # Save to a temporary file
        temp_output = tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False)
        temp_output.close()
        
        try:
            manager.save_to_yaml(temp_output.name)
            
            # Load back and verify
            new_manager = PresetsManager()
            new_manager.load_from_yaml(temp_output.name)
            
            collection = new_manager.get_preset_collection("modern_blue")
            self.assertIsNotNone(collection)
            self.assertEqual(collection.name, "modern_blue")
            
            assignment = new_manager.get_preset_assignment("blue", "airplanes", "all")
            self.assertEqual(assignment, "modern_blue")
        finally:
            os.unlink(temp_output.name)
    
    def test_validate(self):
        """Test validating presets data."""
        # Create valid data
        channels = {
            "channel_01": RadioChannel(freq=243.0, name="Guard")
        }
        radio = Radio(name="radio_1", channels=channels)
        collection = PresetCollection(name="modern_blue", radios={"radio_1": radio})
        presets_def = PresetsDefinition(collections={"modern_blue": collection})
        
        assignments = {
            "blue": {
                "airplanes": {
                    "all": "modern_blue"
                }
            }
        }
        preset_assignment = PresetAssignment(assignments=assignments)
        
        manager = PresetsManager(
            presets_definition=presets_def,
            presets_assignment=preset_assignment
        )
        
        # Should be valid
        self.assertTrue(manager.validate())
        
        # Test with invalid assignment (non-existent collection)
        assignments_invalid = {
            "blue": {
                "airplanes": {
                    "all": "non_existent"
                }
            }
        }
        preset_assignment_invalid = PresetAssignment(assignments=assignments_invalid)
        
        manager_invalid = PresetsManager(
            presets_definition=presets_def,
            presets_assignment=preset_assignment_invalid
        )
        
        # Should be invalid
        self.assertFalse(manager_invalid.validate())


if __name__ == '__main__':
    unittest.main()