"""A briefing says how each tanker refuels (David, 2026-11-17)."""

from __future__ import annotations

from veaf_libs.i18n import language
from veaf_libs.tankers import refuelling_kind, with_refuelling


def test_the_kind_of_each_tanker() -> None:
    assert refuelling_kind("KC-135") == "boom"
    assert refuelling_kind("KC135MPRS") == "basket"
    assert refuelling_kind("KC130") == "basket"
    assert refuelling_kind("KC-10A") == "both"
    assert refuelling_kind("E-3A") is None


def test_the_name_carries_it() -> None:
    with language("fr"):
        assert with_refuelling("Texaco", "KC-135") == "Texaco (boom)"
        assert with_refuelling("Arco", "KC135MPRS") == "Arco (panier)"
        assert with_refuelling("Shell", "KC-10A") == "Shell (boom et panier)"
        assert with_refuelling("Magic", "E-3A") == "Magic"
    with language("en"):
        assert with_refuelling("Arco", "KC135MPRS") == "Arco (basket)"
