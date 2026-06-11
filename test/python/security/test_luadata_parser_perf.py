"""Guard the luadata parser performance refactor (PERF-LUADATA-PARSER).

The refactor (1) stopped re-sorting/rescanning on every append (O(n^2) → O(n))
and (2) skips insignificant whitespace runs in bulk. These tests lock in the
behaviour that could be broken by those optimisations: array ordering, sparse
integer keys, and whitespace-insensitivity.
"""

from __future__ import annotations

import luadata


class TestParserCorrectnessAfterPerfRefactor:
    def test_large_array_order_preserved(self) -> None:
        n = 500
        src = "__c = {" + ", ".join(str(i) for i in range(1, n + 1)) + "}"
        # Pure 1..n array → list, in order.
        assert luadata.unserialize(src) == list(range(1, n + 1))

    def test_out_of_order_explicit_indices(self) -> None:
        src = "__c = { [3]='c', [1]='a', [2]='b' }"
        assert luadata.unserialize(src) == ["a", "b", "c"]

    def test_sparse_integer_keys_stay_dict(self) -> None:
        src = "__c = { [1]='a', [3]='c' }"
        assert luadata.unserialize(src) == {1: "a", 3: "c"}

    def test_whitespace_heavy_is_equivalent(self) -> None:
        compact = "__c={a=1,b={2,3},c='x'}"
        spaced = "__c =  {\n\n    a = 1 ,\n\tb = {\n 2 , 3 \n} ,\n   c = 'x'\n}\n"
        assert luadata.unserialize(spaced, all_is_dict=True) == luadata.unserialize(compact, all_is_dict=True)

    def test_whitespace_inside_strings_preserved(self) -> None:
        # The bulk whitespace-skip must NOT touch whitespace inside string values.
        assert luadata.unserialize('__c = { msg = "a   b\tc" }', all_is_dict=True) == {"msg": "a   b\tc"}
