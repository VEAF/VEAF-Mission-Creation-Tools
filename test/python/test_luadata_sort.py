"""Tests for luadata.serializer.serialize._sort — mixed int/str key crash (SORT-001/002)."""

from __future__ import annotations

import unittest

from luadata.serializer.serialize import _sort


class TestSortMixedKeys(unittest.TestCase):
    """_sort() must not raise when the list contains both int and str elements."""

    def test_sort_all_strings(self) -> None:
        result = _sort(["type", "name", "id"])
        # "id" and "name" and "type" are all priority keys
        self.assertEqual(result[0], "id")
        self.assertEqual(result[1], "name")
        self.assertEqual(result[2], "type")

    def test_sort_mixed_int_str_no_error(self) -> None:
        """Regression: was raising TypeError: '<' not supported between instances of 'int' and 'str'."""
        try:
            result = _sort([1, "name", 2, "type"])
            self.assertIsInstance(result, list)
        except TypeError as exc:
            self.fail(f"_sort raised TypeError on mixed int/str keys: {exc}")

    def test_sort_all_ints_no_error(self) -> None:
        result = _sort([3, 1, 2])
        self.assertIsInstance(result, list)

    def test_sort_empty_list_returns_empty(self) -> None:
        self.assertEqual(_sort([]), [])

    def test_sort_non_list_returned_as_is(self) -> None:
        self.assertEqual(_sort("not a list"), "not a list")  # type: ignore[arg-type]

    def test_priority_keys_come_first(self) -> None:
        result = _sort(["zz_custom", "name", "id", 42])
        # Priority keys (id, name) come before non-priority
        self.assertIn("id", result)
        self.assertIn("name", result)
        id_idx = result.index("id")
        name_idx = result.index("name")
        zz_idx = result.index("zz_custom")
        self.assertLess(id_idx, zz_idx)
        self.assertLess(name_idx, zz_idx)


if __name__ == "__main__":
    unittest.main()
