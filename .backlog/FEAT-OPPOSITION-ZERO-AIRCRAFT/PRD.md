# FEAT-OPPOSITION-ZERO-AIRCRAFT — an opposition level that sends no aircraft

Status: ⬜ ready

## Found

David, 2026-10-15, after *Kolkhida* mission 2: "ajouter un mode 0 avions pour la QRA (opposition)".

Today the level only ever scales the QRA **up**.
The radio menu *Opposition → Niveau* offers « 1 joueur(s) en CAP » to « 8 joueur(s) en CAP », and a QRA with `scale_with_opposition: true` takes the tier of the larger of the level and the count of intruders in its zone (`veafQraManager.md`, *opposition level*).
So even at level 0 — which `follow: air_to_air` reaches when nobody flies CAP — the first intruder still gets the tier of one: on 2026-10-10, with the level fallen to 0, one pair of MiG-29 scrambled from Senaki.
Nothing lets the game master say "no enemy fighters tonight" without editing the mission.

Reading of the request, written here so the session that implements it does not have to ask: **level 0 chosen in the menu (or `_opposition 0`) means the QRA that scale with the opposition do not take off at all**, until the level is raised again.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-zero-aircraft-level.md) | *Niveau → 0 avion*: the QRA that scale with the opposition stay on the ground | ⬜ |

## Related

- `FEAT-OPPOSITION-SCALES-WITH-PLAYERS` — the level, its menu, its marker and its modes.
- `FIX-CAMPAIGN-MISSION-1-FINDINGS` — the campaign the request comes from.
