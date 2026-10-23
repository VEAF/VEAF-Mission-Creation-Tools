"""`missing_accents_warning` — a French text written without a single accent (FIX-DEMO-VIDEO-FINDINGS 06).

Measured on two free models' runs: accented French in the reasoning, unaccented in the JavaScript passed to
`execute` (`colonne blindee`, `noeud logistique`, `Detruire`). The warning never refuses and never fires on a
text that has an accent, on English, or on a text too short to judge.
"""

from veaf_mission_mcp.accents import missing_accents_warning, missing_accents_warnings

_UNACCENTED = (
    "13 octobre 2015, 06h15. La colonne blindee qui a force le defile de Mitla a depasse sa logistique : "
    "elle est arretee faute de carburant au sud-est de Bir Gifgafa."
)


def test_an_unaccented_french_text_warns_and_names_the_fix() -> None:
    warning = missing_accents_warning("situation", _UNACCENTED)
    assert warning is not None
    assert "situation" in warning
    assert "accent" in warning
    assert "blindee" in warning


def test_the_same_text_with_its_accents_does_not_warn() -> None:
    accented = (
        "13 octobre 2015, 06h15. La colonne blindée qui a forcé le défilé de Mitla a dépassé sa logistique : "
        "elle est arrêtée faute de carburant au sud-est de Bir Gifgafa."
    )
    assert missing_accents_warning("situation", accented) is None


def test_an_english_text_does_not_warn() -> None:
    english = "The armoured column that forced the Mitla pass has outrun its logistics and stopped for fuel."
    assert missing_accents_warning("situation", english) is None


def test_a_short_text_is_not_judged() -> None:
    assert missing_accents_warning("title", "Detruire le noeud") is None


def test_one_ambiguous_word_is_not_enough() -> None:
    # `defile` is English too: a single hit proves nothing
    assert (
        missing_accents_warning("note", "The column stopped at the defile three kilometres east of the road.") is None
    )


def test_several_texts_give_one_warning_each_and_skip_the_empty_ones() -> None:
    warnings = missing_accents_warnings({"situation": _UNACCENTED, "blue_task": "", "sortie": None, "note": "ok"})
    assert len(warnings) == 1
    assert "situation" in warnings[0]
