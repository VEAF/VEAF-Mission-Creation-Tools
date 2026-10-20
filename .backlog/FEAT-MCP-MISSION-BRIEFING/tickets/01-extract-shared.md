# 01 — Extract the campaign-free pieces

Status: ✅ done

The ATO, frequency and navigation pages, the weather lines, the map canvas and the picture page move out of `mission_deck.py` / `tactical_map.py` into a module the campaign and the one-shot builder share. The campaign deck's frequency page loses its Guard line.

Done: the campaign deck tests stay green, with the Guard assertion changed.
