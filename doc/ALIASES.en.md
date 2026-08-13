# Aliases Reference

Quick-reference of all built-in marker aliases available in every VEAF MCT mission.

Place an F10 map marker with the alias text (e.g. `-sam`) to spawn the corresponding group or execute the command. See [veafShortcuts](mission-maker/scripts/veafShortcuts.en.md) for the module documentation and how to create custom aliases.

---

## Generic SAM Groups

| Alias | Description | Notes |
|-------|-------------|-------|
| `-sam` | Random SAM battery | Defense level 1–5 (random) |
| `-samLR` | Random long-range SAM battery | Defense level 4–5 (random) |
| `-samSR` | Random short-range SAM battery | Defense level 2–3 (random) |
| `-aaa` | Random AAA battery | Defense level 1–2 (random) |

## Red Air Defenses (specific systems)

| Alias | Description |
|-------|-------------|
| `-hq7` | HQ-7 (Red Banner) battery |
| `-hq7_single` | HQ-7 single launcher |
| `-hq7noew` | HQ-7 battery without EWR |
| `-hq7eo` | HQ-7EO battery |
| `-hq7eo_single` | HQ-7EO single launcher |
| `-hq7eo_noew` | HQ-7EO battery without EWR |
| `-sa2` | SA-2 Guideline (S-75 Dvina) battery |
| `-sa3` | SA-3 Goa (S-125 Neva/Pechora) battery |
| `-sa5` | SA-5 Gammon (S-200 Dubna) battery |
| `-sa6` | SA-6 Gainful (2K12 Kub) battery |
| `-sa8` | SA-8 Osa (9K33) squad |
| `-sa9` | SA-9 Strela-1 vehicle |
| `-sa9_squad` | SA-9 Strela-1 with logistics |
| `-sa10` | SA-10 Grumble (S-300) battery |
| `-sa11` | SA-11 Gadfly (9K37 Buk) battery |
| `-sa13` | SA-13 Strela-10M3 vehicle |
| `-sa13_squad` | SA-13 with logistics |
| `-sa15` | SA-15 Gauntlet (9K330 Tor) squad |
| `-sa15m2` | SA-15M2 Gauntlet (Tor-M2) squad |
| `-sa19` | SA-19 Tunguska (2K22) squad |
| `-sa22` | SA-22 Greyhound (Pantsir-S1) squad |
| `-sa18` | SA-18 MANPAD squad |
| `-sa18s` | SA-18S MANPAD squad |
| `-insurgent_manpad` | Insurgent SA-18 MANPAD squad |
| `-manpads` | Multiple SA-18S scattered in wide radius (3–6 units) |
| `-shilka` | ZSU-23-4 Shilka AAA |
| `-zu23` | ZU-23 on Ural truck |

## Blue Air Defenses

| Alias | Description |
|-------|-------------|
| `-rapier` | Rapier battery with radar (US) |
| `-roland` | Roland battery with EWR (US) |
| `-rolandnoew` | Roland battery without EWR (US) |
| `-nasams` | NASAMS battery with AIM-120C (US) |
| `-nasams_b` | NASAMS battery with AIM-120B (US) |
| `-hawk` | Hawk battery (US) |
| `-patriot` | Patriot battery (US) |
| `-stinger` | Stinger MANPAD squad (US) |
| `-avenger` | Avenger SAM vehicle (US) |
| `-avenger_squad` | Avenger with logistics (US) |

## EWR / Radar

| Alias | Description |
|-------|-------------|
| `-ewr` | 55G6 Mast EWR |
| `-dogear` | Dog Ear radar |
| `-blue_ewr` | F-117 Domed EWR (US) |

## Naval

| Alias | Description |
|-------|-------------|
| `-burke` | USS Arleigh Burke IIa destroyer (US) |
| `-perry` | O.H. Perry frigate (US) |
| `-ticonderoga` | Ticonderoga cruiser (US) |
| `-rezky` | FF 1135M Rezky frigate (RU) |
| `-pyotr` | CGN 1144.2 Pyotr Velikiy (RU) |
| `-cargoships` | Cargo ships (RU) |
| `-escortedcargoships` | Cargo ships with escort (RU) |
| `-combatships` | Combat ships (RU) |

## Dynamic Ground Groups

| Alias | Description | Notes |
|-------|-------------|-------|
| `-armor` | Dynamic armor group | Random defense/armor/size |
| `-infantry` | Dynamic infantry section | Random defense/armor/size |
| `-transport` | Dynamic transport company | Random defense/size |
| `-combat` | Dynamic combat group | Random defense/armor/size |
| `-cas` | Random CAS training group | Dispersed |

## Convoys

| Alias | Description |
|-------|-------------|
| `-convoy` | Dynamic convoy (needs `, dest POINTNAME`) |
| `-hv_convoy_red` | Red high-value attack convoy (with Scud) |
| `-attack_convoy_red` | Red attack convoy |
| `-QRC_red` | Red Quick Reaction Convoy |
| `-civilian_convoy_red` | Red civilian convoy |
| `-QRC_blue` | Blue Quick Reaction Convoy |

## Artillery

| Alias | Description |
|-------|-------------|
| `-arty` | M-109 battery (US) |
| `-mortar` | Mortar team (US) |
| `-msta` | Msta battery (RU) |
| `-plz05` | PLZ-05 battery (CN) |
| `-mlrs` | MLRS battery (US) |
| `-smerch_he` | Smerch HE battery (RU) |
| `-smerch_cm` | Smerch CM battery (RU) |
| `-uragan` | Uragan battery (RU) |
| `-grad` | Grad battery (RU) |
| `-arty1` | Spawn ARTY-1 with AI handler |
| `-arty1_aim` | ARTY-1: fire for aim at marker |
| `-arty1_fire` | ARTY-1: fire for effect at marker |
| `-arty1_stop` | ARTY-1: stop listening |
| `-arty1_start` | ARTY-1: start listening |
| `-arty2` | Spawn ARTY-2 with AI handler |
| `-arty2_aim` | ARTY-2: fire for aim at marker |
| `-arty2_fire` | ARTY-2: fire for effect at marker |
| `-arty2_stop` | ARTY-2: stop listening |
| `-arty2_start` | ARTY-2: start listening |
| `-arty3` | Spawn ARTY-3 with AI handler |
| `-arty3_aim` | ARTY-3: fire for aim at marker |
| `-arty3_fire` | ARTY-3: fire for effect at marker |
| `-arty3_stop` | ARTY-3: stop listening |
| `-arty3_start` | ARTY-3: start listening |

### Simulated shelling

These three simulate artillery fire by spawning explosions (`_spawn bomb`); shell count, radius and
power are each drawn at random from a range.

| Alias | Description |
|-------|-------------|
| `-cesar` | Precision shelling of a zone, a few low-yield HE rounds |
| `-shell` | Shelling of a small zone with lots of low-yield HE |
| `-flak` | Anti-air artillery: flak at 6,000 ft above the marker |

## Support & Utility

| Alias | Description |
|-------|-------------|
| `-jtac` | JTAC humvee |
| `-afac` | AFAC MQ-9 Reaper |
| `-afachere` | Move AFAC to location (needs group name) |
| `-cargo` | Cargo for sling loading (blue) |
| `-refuel` | US refuel group |
| `-tankerhere` | Move tanker to location (needs group name) |
| `-tanker` | Alias for `-tankerhere` |
| `-tankerlow` | Set closest tanker to FL120 / 200 KIAS |
| `-tankerhigh` | Set closest tanker to FL220 / 300 KIAS |
| `-tacan` | Portable TACAN beacon (X band, ch 99) |
| `-farp` | Create a FARP (needs name) |
| `-farpNoMarker` | Create invisible FARP (needs name) |
| `-fob` | Create a FOB |

## Effects

| Alias | Description |
|-------|-------------|
| `-smoke` | Single white smoke |
| `-longsmoke` | White smoke renewed every 5 min for 30 min |
| `-signal` | Single green signal flare |
| `-light` | Illumination flares above area |

## Air Missions

| Alias | Description |
|-------|-------------|
| `-cap` | Dynamic CAP (needs aircraft name) |
| `-airstart` | Start a combat mission (needs name) |
| `-airstop` | Stop a combat mission (needs name) |
| `-zonestart` | Activate a combat zone (needs name) |
| `-zonestop` | Deactivate a combat zone (needs name) |

## Radio

| Alias | Description |
|-------|-------------|
| `-send` | Send a radio message (needs `"MESSAGE"`) |
| `-play` | Play a sound file (needs `"FILENAME"`) |

## Mission Master

| Alias | Description |
|-------|-------------|
| `-flag` | Get flag value (needs name) |
| `-flagon` | Set flag to ON (needs name) |
| `-flagoff` | Set flag to OFF (needs name) |
| `-run` | Execute a runnable (needs name) |

## Utility Commands

| Alias | Description |
|-------|-------------|
| `-destroy` | Destroy any unit within 100 m of marker |
| `-ai_set` | Configure AI handler for a ground group |
| `-login` | Unlock the system (takes the password — see below) |
| `-logout` | Lock the system again |

> 🔐 `-login` and `-logout` drive VEAF authentication (`_auth`). `-login` expects the password right
> after it, **with no comma**: `-login mypassword`. They carry `:setHidden(true)`, which keeps them out
> of the list the `list_shortcuts` MCP action serves to an AI — you do not offer an authentication
> command to an assistant building a mission.

## Map Tools

| Alias | Description |
|-------|-------------|
| `-point` | Name a point on the map |
| `-draw` | Start/continue a drawing (needs name) |
| `-arrow` | Start/continue an arrow drawing (needs name) |
| `-square` | Draw a square (needs name) |
| `-circle` | Draw a circle (needs name) |
| `-erasedrawing` | Erase a drawing (needs name) |

---

## See also

- [veafShortcuts module](mission-maker/scripts/veafShortcuts.en.md) — module documentation, custom alias creation
- [veafSpawn](mission-maker/scripts/veafSpawn.en.md) — the underlying spawn engine
