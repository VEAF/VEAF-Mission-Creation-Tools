import unittest
from pathlib import Path
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from presets_manager import (
    Channel,
    ChannelDefinition,
    ChannelCollection,
    RadioDefinition,
    RadioCollection,
    PresetDefinition,
    PresetCollection,
    PresetAssignment,
    PresetAssignmentCollection,
    PresetsManager,
)


class TestPresets(unittest.TestCase):

    def test_channel(self):
        # Test Channel dataclass
        channel = Channel(name_or_number="01", freq=123.456, title="Test Title")
        self.assertEqual(channel.number, 1)
        self.assertEqual(channel.freq, 123.456)
        self.assertEqual(channel.title, "Test Title")

        # Test without title
        channel_no_title = Channel(name_or_number="channel_2", freq=234.567)
        self.assertEqual(channel_no_title.number, 2)
        self.assertEqual(channel_no_title.freq, 234.567)
        self.assertIsNone(channel_no_title.title)

    def test_channel_definition_init(self):
        # Test ChannelDefinition __init__
        cd = ChannelDefinition(name="test_cd", title="Test CD", misc_data="misc", collection_name="test_coll")
        self.assertEqual(cd.name, "test_cd")
        self.assertEqual(cd.title, "Test CD")
        self.assertEqual(cd.misc_data, "misc")
        self.assertEqual(cd.collection_name, "test_coll")
        self.assertEqual(cd.frequencies, {})

    def test_channel_definition_add_freq(self):
        cd = ChannelDefinition(name="test_cd")
        cd.add_freq("uhf", 225.0)
        self.assertEqual(cd.frequencies["uhf"], 225.0)

        cd.add_freq("vhf", "131.000")
        self.assertEqual(cd.frequencies["vhf"], 131.0)

        # Test invalid mode
        with self.assertRaises(ValueError):
            cd.add_freq("", 225.0)

        # Test invalid freq
        with self.assertRaises(ValueError):
            cd.add_freq("uhf", "")

        with self.assertRaises(ValueError):
            cd.add_freq("uhf", 0)

        with self.assertRaises(ValueError):
            cd.add_freq("uhf", "invalid")

    def test_channel_definition_from_dict(self):
        data = {
            "title": "Test Channel",
            "data": "misc data",
            "freqs": {
                "uhf": 225.0,
                "vhf": 131.0
            }
        }
        cd = ChannelDefinition.from_dict("test_channel", data)
        self.assertEqual(cd.name, "test_channel")
        self.assertEqual(cd.title, "Test Channel")
        self.assertEqual(cd.misc_data, "misc data")
        self.assertEqual(cd.frequencies["uhf"], 225.0)
        self.assertEqual(cd.frequencies["vhf"], 131.0)

        # Test missing freqs
        data_no_freqs = {"title": "Test"}
        with self.assertRaises(ValueError):
            ChannelDefinition.from_dict("test", data_no_freqs)

    def test_channel_collection_init(self):
        cc = ChannelCollection(name="test_cc")
        self.assertEqual(cc.name, "test_cc")
        self.assertEqual(cc.channel_definitions, {})

    def test_channel_collection_add_channel_definition(self):
        cc = ChannelCollection(name="test_cc")
        cd = ChannelDefinition(name="test_cd")
        cc.add_channel_definition(cd)
        self.assertEqual(cc.channel_definitions["test_cd"], cd)
        self.assertEqual(cd.collection_name, "test_cc")

        # Test invalid channel
        with self.assertRaises(ValueError):
            cc.add_channel_definition(None)

        cd_no_name = ChannelDefinition(name="")
        with self.assertRaises(ValueError):
            cc.add_channel_definition(cd_no_name)

    def test_channel_collection_from_dict(self):
        data = {
            "channel1": {
                "title": "Channel 1",
                "freqs": {"uhf": 225.0}
            },
            "channel2": {
                "title": "Channel 2",
                "freqs": {"vhf": 131.0}
            }
        }
        cc = ChannelCollection.from_dict("test_cc", data)
        self.assertEqual(cc.name, "test_cc")
        self.assertIn("channel1", cc.channel_definitions)
        self.assertIn("channel2", cc.channel_definitions)
        self.assertEqual(cc.channel_definitions["channel1"].frequencies["uhf"], 225.0)

    def test_radio_definition_init(self):
        rd = RadioDefinition(name="test_radio", radio_type="uhf", title="Test Radio")
        self.assertEqual(rd.name, "test_radio")
        self.assertEqual(rd.radio_type, "uhf")
        self.assertEqual(rd.title, "Test Radio")
        self.assertEqual(rd.channels, [])

    def test_radio_definition_add_channel(self):
        rd = RadioDefinition(name="test_radio", radio_type="uhf")
        channel = Channel(name_or_number="channel_01", freq=225.0)
        self.assertEqual(channel.number, 1)
        rd.add_channel(channel)
        self.assertEqual(len(rd.channels), 1)
        self.assertEqual(rd.channels[0], channel)

        # Test invalid channel
        with self.assertRaises(ValueError):
            rd.add_channel(None)

    def test_radio_definition_to_dict(self):
        rd = RadioDefinition(name="test_radio", radio_type="uhf")
        channel1 = Channel(name_or_number="01", title="Test1", freq=225.0)
        channel2 = Channel(name_or_number="02", title="Test2", freq=243.0)
        rd.add_channel(channel1)
        rd.add_channel(channel2)
        result = rd.to_dict()
        expected = {
            "channelsNames": {1: "Test1", 2: "Test2"},
            "channels": {1: 225.0, 2: 243.0}
        }
        self.assertEqual(result, expected)

    def test_radio_definition_from_dict(self):
        channel_collections = {
            "test_coll": ChannelCollection("test_coll")
        }
        cd = ChannelDefinition(name="guard", title="Guard")
        cd.add_freq("uhf", 243.0)
        channel_collections["test_coll"].add_channel_definition(cd)

        data = {
            "title": "Test Radio",
            "type": "uhf",
            "channels": {
                "01": {"channel": "guard", "title": "Guard/UHF"},
                "02": {"freq": 225.0}
            }
        }
        rd = RadioDefinition.from_dict("test_radio", data, channel_collections)
        self.assertEqual(rd.name, "test_radio")
        self.assertEqual(rd.title, "Test Radio")
        self.assertEqual(rd.radio_type, "uhf")
        self.assertEqual(len(rd.channels), 2)
        self.assertEqual(rd.channels[0].number, 1)
        self.assertEqual(rd.channels[0].freq, 243.0)
        self.assertEqual(rd.channels[1].number, 2)
        self.assertEqual(rd.channels[1].freq, 225.0)

        # Test missing type
        data_no_type = {"channels": {"01": {"freq": 225.0}}}
        with self.assertRaises(ValueError):
            RadioDefinition.from_dict("test", data_no_type, channel_collections)

        # Test missing channels
        data_no_channels = {"type": "uhf"}
        with self.assertRaises(ValueError):
            RadioDefinition.from_dict("test", data_no_channels, channel_collections)

        # Test channel alias not found
        data_bad_alias = {"type": "uhf", "channels": {"01": {"channel": "nonexistent"}}}
        with self.assertRaises(ValueError):
            RadioDefinition.from_dict("test", data_bad_alias, channel_collections)

        # Test channel with string shortcut for alias
        data_string_alias = {"type": "uhf", "channels": {"01": "guard"}}
        rd_string = RadioDefinition.from_dict("test_radio_string", data_string_alias, channel_collections)
        self.assertEqual(rd_string.channels[0].freq, 243.0)

        # Test channel with int shortcut for freq
        data_int_freq = {"type": "uhf", "channels": {"01": 225}}
        rd_int = RadioDefinition.from_dict("test_radio_int", data_int_freq, channel_collections)
        self.assertEqual(rd_int.channels[0].freq, 225.0)

    def test_radio_collection_init(self):
        rc = RadioCollection(name="test_rc")
        self.assertEqual(rc.name, "test_rc")
        self.assertEqual(rc.radio_definitions, {})

    def test_radio_collection_add_radio_definition(self):
        rc = RadioCollection(name="test_rc")
        rd = RadioDefinition(name="test_radio", radio_type="uhf")
        rc.add_radio_definition(rd)
        self.assertEqual(rc.radio_definitions["test_radio"], rd)
        self.assertEqual(rd.collection_name, "test_rc")

        # Test invalid radio
        with self.assertRaises(ValueError):
            rc.add_radio_definition(None)

        rd_no_name = RadioDefinition(name="", radio_type="uhf")
        with self.assertRaises(ValueError):
            rc.add_radio_definition(rd_no_name)

    def test_radio_collection_from_dict(self):
        channel_collections = {}
        data = {
            "radio1": {
                "type": "uhf",
                "channels": {"01": {"freq": 225.0}}
            }
        }
        rc = RadioCollection.from_dict("test_rc", data, channel_collections)
        self.assertIsInstance(rc, RadioCollection)
        self.assertEqual(rc.name, "test_rc")
        self.assertIn("radio1", rc.radio_definitions)
        self.assertEqual(rc.radio_definitions["radio1"].radio_type, "uhf")

    def test_preset_definition_init(self):
        pd = PresetDefinition(name="test_preset")
        self.assertEqual(pd.name, "test_preset")
        self.assertEqual(pd.radios, {})

    def test_preset_definition_add_radio(self):
        pd = PresetDefinition(name="test_preset")
        rd = RadioDefinition(name="test_radio", radio_type="uhf")
        pd.add_radio(rd)
        self.assertEqual(len(pd.radios), 1)
        self.assertEqual(pd.radios["test_radio"], rd)

        # Test invalid radio
        with self.assertRaises(ValueError):
            pd.add_radio(None)

    def test_preset_definition_to_dict(self):
        pd = PresetDefinition(name="test_preset")
        rd1 = RadioDefinition(name="radio1", radio_type="uhf")
        rd2 = RadioDefinition(name="radio2", radio_type="vhf")
        pd.radios = {"1": rd1, "2": rd2}
        result = pd.to_dict()
        expected = {
            1: {"channelsNames": {}, "channels": {}},
            2: {"channelsNames": {}, "channels": {}}
        }
        self.assertEqual(result, expected)

    def test_preset_definition_from_dict(self):
        radio_collections = {}
        # Create a radio collection with a radio
        rc = RadioCollection("test_rc")
        rd = RadioDefinition("radio1", "uhf")
        rc.add_radio_definition(rd)
        radio_collections["test_rc"] = rc

        data = {
            "radios": {
                "radio1": "radio1"
            }
        }
        pd = PresetDefinition.from_dict("test_preset", data, radio_collections)
        self.assertEqual(pd.name, "test_preset")
        self.assertEqual(len(pd.radios), 1)
        self.assertEqual(pd.radios["radio1"].name, "radio1")

        # Test missing radios
        data_no_radios = {}
        with self.assertRaises(ValueError):
            PresetDefinition.from_dict("test", data_no_radios, radio_collections)

    def test_preset_collection_init(self):
        pc = PresetCollection(name="test_pc")
        self.assertEqual(pc.name, "test_pc")
        self.assertEqual(pc.preset_definitions, {})

    def test_preset_collection_add_preset_definition(self):
        pc = PresetCollection(name="test_pc")
        pd = PresetDefinition(name="test_preset")
        pc.add_preset_definition(pd)
        self.assertEqual(pc.preset_definitions["test_preset"], pd)
        self.assertEqual(pd.collection_name, "test_pc")

        # Test invalid preset
        with self.assertRaises(ValueError):
            pc.add_preset_definition(None)

        pd_no_name = PresetDefinition(name="")
        with self.assertRaises(ValueError):
            pc.add_preset_definition(pd_no_name)

    def test_preset_collection_from_dict(self):
        radio_collections = {}
        # Create a radio collection with a radio
        rc = RadioCollection("test_rc")
        rd = RadioDefinition("radio1", "uhf")
        rc.add_radio_definition(rd)
        radio_collections["test_rc"] = rc

        data = {
            "preset1": {
                "radios": {
                    "radio1": "radio1"
                }
            }
        }
        pc = PresetCollection.from_dict("test_pc", data, radio_collections)
        self.assertIsInstance(pc, PresetCollection)
        self.assertEqual(pc.name, "test_pc")
        self.assertIn("preset1", pc.preset_definitions)
        self.assertEqual(pc.preset_definitions["preset1"].name, "preset1")

    def test_preset_assignment(self):
        # Test PresetAssignment dataclass
        pd = PresetDefinition(name="test_preset")
        pa = PresetAssignment(preset_definition=pd, coalition="blue", aircraft_type="plane", unit_type="F-16")
        self.assertEqual(pa.coalition, "blue")
        self.assertEqual(pa.aircraft_type, "plane")
        self.assertEqual(pa.unit_type, "F-16")
        self.assertEqual(pa.preset_definition.name, "test_preset")

        # Test defaults
        pa_default = PresetAssignment(preset_definition=pd)
        self.assertEqual(pa_default.coalition, "all")
        self.assertEqual(pa_default.aircraft_type, "all")
        self.assertEqual(pa_default.unit_type, "all")
        self.assertEqual(pa_default.preset_definition.name, "test_preset")

    def test_preset_assignment_collection_from_dict(self):
        # Create preset collections
        preset_collections = {}
        pc = PresetCollection("test_pc")
        pd1 = PresetDefinition("modern_blue_uhf_vhf_fm")
        pd2 = PresetDefinition("modern_blue_vhf_uhf_fm")
        pc.add_preset_definition(pd1)
        pc.add_preset_definition(pd2)
        preset_collections["test_pc"] = pc

        data = {
            "blue": {
                "plane": {
                    "all": "modern_blue_uhf_vhf_fm",
                    "F-16": "modern_blue_vhf_uhf_fm"
                }
            }
        }
        pac = PresetAssignmentCollection.from_dict(data, preset_collections)
        self.assertIsInstance(pac, PresetAssignmentCollection)
        # Test get_preset_for
        preset = pac.get_preset_for("blue", "plane", "all")
        self.assertEqual(preset.preset_definition.name, "modern_blue_uhf_vhf_fm")

        preset_specific = pac.get_preset_for("blue", "plane", "F-16")
        self.assertEqual(preset_specific.preset_definition.name, "modern_blue_vhf_uhf_fm")

        preset_fallback = pac.get_preset_for("blue", "plane", "unknown")
        self.assertEqual(preset_fallback.preset_definition.name, "modern_blue_uhf_vhf_fm")

        preset_none = pac.get_preset_for("red", "plane", "all")
        self.assertIsNone(preset_none)

    def test_presets_manager_init(self):
        pm = PresetsManager()
        self.assertEqual(pm.channel_collections, {})
        self.assertEqual(pm.radio_collections, {})
        self.assertEqual(pm.preset_collections, {})
        self.assertIsInstance(pm.preset_assignments, PresetAssignmentCollection)

    def test_presets_manager_read_yaml(self):
        # Test loading the provided YAML file
        pm = PresetsManager()
        yaml_path = Path("./src/defaults/mission-folder/src/presets.yaml")
        try:
            pm.read_yaml(yaml_path)
            # Check that collections are populated
            self.assertGreater(len(pm.channel_collections), 0)
            self.assertGreater(len(pm.radio_collections), 0)
            self.assertGreater(len(pm.preset_collections), 0)
            # Test get_radios_for
            preset = pm.get_radios_for("blue", "plane", "all")
            self.assertIsNotNone(preset)
        except Exception as e:
            # Skip this test if the YAML file has issues
            self.fail(f"YAML loading failed: {e}")

    def test_presets_manager_write_yaml(self):
        # Test write_yaml (currently not implemented)
        pm = PresetsManager()
        yaml_path = Path("test_output.yaml")
        # Should not raise exception, but does nothing
        pm.write_yaml(yaml_path)
        # Check if file was created (it shouldn't be)
        self.assertFalse(yaml_path.exists())


if __name__ == '__main__':
    unittest.main()