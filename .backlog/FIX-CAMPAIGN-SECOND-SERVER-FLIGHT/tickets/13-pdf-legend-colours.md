# 13 — The theatre dossier's PDF legend is black

Status: ⬜ ready
Type: fix

## Found

David, 2026-11-17: on the "Carte du réseau" and "Défenses aériennes connues" pages of the theatre dossier, the legend's "Tenu par les bleus / rouges / Neutre" dots are all black.
`map_notes` (`campaign_manager/briefing_deck.py`) puts the dot in the text (`"● …"`), and `MapSheet.notes` is only `(text, is_heading)`: `briefing_pdf._map_page` writes everything in black. The PPTX colours the dot (`_write_map`). Same on the campaign deck's strategic map.

## To do

- A map note may carry a colour for its dot; `_map_page` draws the dot in that colour and the text in black.
- A test on the PDF (the dot's colour in the page's content stream, or the note's colour reaching `_map_page`).
- Regenerate the Oronte dossier and the pictures of the campaign's follow-up document.

## Done when

The three dots of the PDF legend are blue, red and grey.
