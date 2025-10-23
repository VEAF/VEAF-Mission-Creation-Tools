#!/usr/bin/env python3

import sys
import os
sys.path.append('src/python/veaf-tools/presets_injector')

from presets_manager import PresetsManager

def test_load_yaml():
    yaml_path = 'src/defaults/mission-folder/src/presets.yaml'
    manager = PresetsManager()
    manager.load_from_yaml(yaml_path)
    
    print("Radios Definition:")
    for name, radio in manager.radios_definition.radios.items():
        print(f"  {name}: {radio.title} with {len(radio.channels)} channels")
    
    print("\nPresets Definition:")
    for name, collection in manager.presets_definition.collections.items():
        print(f"  {name}: {collection.title}")
        for slot, alias in collection.radios.items():
            print(f"    {slot}: {alias}")
    
    print("\nPresets Assignment:")
    for coalition, types in manager.presets_assignment.assignments.items():
        print(f"  {coalition}:")
        for aircraft_type, groups in types.items():
            print(f"    {aircraft_type}: {groups}")

if __name__ == "__main__":
    test_load_yaml()