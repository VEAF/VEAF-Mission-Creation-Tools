# 02 — recon-plan: one shot per combat zone

Status: 🔄 in progress

- One shot per combat zone of the running mission (`veafCombatZone.zonesList`), operations excluded; nothing else on the map.
- With `docs/kneeboard.json` beside it, the shots follow its objectives, in its order, with its titles; zones it does not list are left out.
- `--from <airbase>` aims every shot from that airbase towards its zone; without it the heading stays 0, to be set by hand.
- The slant is `auto`: computed at the shot from the units' spread, capped at 6 km.
- The folder of `--out` is created.
