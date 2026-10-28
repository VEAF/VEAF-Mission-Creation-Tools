# 03 — Locator inset on the zooms, target sheets

Status: ✅ done

Each objective zoom carries a small inset of the overview with the zoom's place marked. The target coordinates become sheets, several per slide: name, what it is (unit type and count), coordinates in DMS and degrees-decimal-minutes, elevation, and a thumbnail cut from the zoom.

Done when: the behaviour is covered by a test, and the action's documentation says it.

## Result

`Inset` on every zoom (deck and kneeboard), the zoom's place circled on the overview. `briefing_cards.py`: `Card`, `CardSection`, six to a slide in the deck and the PDF; a target's card carries its units' types (`Target.kind`), DMS and DDM, elevation, a thumbnail of its zoom. Tests: `test_briefing_cards.py`, `TestTheInset`, `TestTheSheets`.
