# 05 — Submenu per pilot in multi-slot groups

Status: 🧑 waiting-human (code done; checked in game with two players in one group)

## Done when

- `veafRadio.addSubMenuPerPilot`: in a group, each present pilot gets the menu's entries under a submenu with his player name, bound to his unit, so the answer can go to him alone (`veaf.outTextForUnit`); a pilot alone gets them directly.
- Lua tests; checked in game with two players in one group.
- A demo mission step needs a mission script calling `addSubMenuPerPilot`: left to a follow-up in VEAF-Demo-Mission-v6.
