"""
VEAF Mission Normalizer Package.
"""

from typing import Any
from .miz_tools import DcsMission
import functools


class MissionNormalizer:
    """
    A class that normalizes a mission, based on a DcsMission object.
    Normalizes by sorting tables by ID and removing unused dictionary keys.
    """

    def __init__(self, dcs_mission: DcsMission):
        """
        Initialize.
        """
        self.keys_to_sort_by_id: set[str] = {"country"}
        self.dcs_mission = dcs_mission

    def _sort_table(self, t, level: int = 0):
        """
        Recursively sort a table (dict/list), with special handling for ID-based sorting.
        """
        if not isinstance(t, dict):
            return t

        # Create a new sorted dict
        result = {}

        # Sort keys case-insensitively for strings, numerically for numbers
        def sort_key(key):
            return key.lower() if isinstance(key, str) else key

        sorted_keys = sorted(t.keys(), key=sort_key)

        for key in sorted_keys:
            value = t[key]

            if key in self.keys_to_sort_by_id and isinstance(value, list):
                # Sort by ID using comparison function like Lua
                def sort_by_id(a, b):
                    if isinstance(a, dict) and "id" in a:
                        id_a = a["id"]
                        if isinstance(id_a, str) and id_a.isdigit():
                            id_a = int(id_a)
                        elif not isinstance(id_a, (int, float)):
                            id_a = 0
                    else:
                        return False

                    if isinstance(b, dict) and "id" in b:
                        id_b = b["id"]
                        if isinstance(id_b, str) and id_b.isdigit():
                            id_b = int(id_b)
                        elif not isinstance(id_b, (int, float)):
                            id_b = 0
                        return id_a < id_b
                    else:
                        return False

                result[key] = sorted(value, key=functools.cmp_to_key(sort_by_id))
            else:
                result[key] = value

            # Recurse
            if isinstance(result[key], (dict, list)):
                result[key] = self._sort_table(result[key], level + 1)

        return result

    def _recursively_search_for_dictionary_keys(self, t: Any, dictionary_keys: set[str]) -> None:
        """
        Recursively search for dictionary keys in a table.
        Dictionary keys are identified by containing "DictKey_" (case insensitive).
        """
        if isinstance(t, dict):
            for key, value in t.items():
                if isinstance(value, (dict, list)):
                    self._recursively_search_for_dictionary_keys(value, dictionary_keys)
                elif isinstance(value, str):
                    if "dictkey_" in value.lower():
                        dictionary_keys.add(value.lower())
        elif isinstance(t, list):
            for item in t:
                if isinstance(item, (dict, list)):
                    self._recursively_search_for_dictionary_keys(item, dictionary_keys)

    def _process_mission_content(self, mission_content: dict[str, Any]) -> dict[str, Any]:
        """
        Process the mission content: search for dictionary keys and sort.
        """
        # Find all dictionary keys used in the mission
        dictionary_keys_used: set[str] = set()
        self._recursively_search_for_dictionary_keys(mission_content, dictionary_keys_used)

        # Store for later use in dictionary processing
        self.dictionary_keys_used = dictionary_keys_used

        # Sort the mission content
        return self._sort_table(mission_content)

    def _process_dictionary_content(self, dictionary_content: dict[str, str]) -> dict[str, str]:
        """
        Process the dictionary content: keep only used keys and sort.
        """
        if not hasattr(self, 'dictionary_keys_used'):
            return dictionary_content

        result = {
            key: value
            for key, value in dictionary_content.items()
            if key.lower() in self.dictionary_keys_used
        }

        # Sort the result
        return self._sort_table(result)

    def _process_warehouses_content(self, warehouses_content: dict[str, Any]) -> dict[str, Any]:
        """
        Process the warehouses content: just sort.
        """
        return self._sort_table(warehouses_content)

    def _process_map_resource_content(self, map_resource_content: dict[str, str]) -> dict[str, str]:
        """
        Process the mapResource content: just sort.
        """
        return self._sort_table(map_resource_content)

    def normalize_mission(self) -> DcsMission:
        """
        Normalize the mission by sorting and cleaning up dictionary keys.
        """

        # Process mission content first (to find used dictionary keys)
        if self.dcs_mission.mission_content:
            self.dcs_mission.mission_content = self._process_mission_content(self.dcs_mission.mission_content)

        # Process dictionary content
        if self.dcs_mission.dictionary_content:
            self.dcs_mission.dictionary_content = self._process_dictionary_content(self.dcs_mission.dictionary_content)

        # Process warehouses content
        if self.dcs_mission.warehouses_content:
            self.dcs_mission.warehouses_content = self._process_warehouses_content(self.dcs_mission.warehouses_content)

        # Process mapResource content
        if self.dcs_mission.map_resource_content:
            self.dcs_mission.map_resource_content = self._process_map_resource_content(self.dcs_mission.map_resource_content)

        # Options and theatre are not processed in the Lua version
        # options is commented out, theatre is not mentioned

        return self.dcs_mission