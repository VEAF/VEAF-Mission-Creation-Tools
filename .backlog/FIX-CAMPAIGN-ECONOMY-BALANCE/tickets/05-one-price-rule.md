# 05 — One price rule, fixed at its source

Status: ✅ done (in-game check pending)
Type: fix

## Decided

David, 2026-11-20 (option b of the price question, then option a of this ticket's): the shop must not mix Foothold's prices with others 5 to 10 times cheaper.
Upgrades cost their units' spawn price; fix that price where it is wrong instead of hand prices on top of it.

## Measured (2026-11-20, `dcsUnits.lua`)

The DCS unit database marks a SAM launcher `SAM LL` and a command post `SAM CC`; neither carries the system's range (`MR SAM`, `LR SAM`), which only the radars (and the SA-11 and S-125 launchers) carry. `veafCampaign.unitPrice` read them as guns, 8 points:

| Type | Attributes that matter | Price before |
|---|---|---|
| `Hawk ln`, `NASAMS_LN_B/C`, `Patriot ln`, `S-300PS 5P85C/D ln`, `Kub 2P25 ln` | `SAM LL`, `AA_missile` | 8 |
| `Hawk pcp`, `NASAMS_Command_Post`, `Patriot cp/ECS/EPP/AMG`, `S-300PS 54K6 cp` | `SAM CC` | 8 |
| `Hawk sr/cwar/tr`, `NASAMS_Radar_MPQ64F1`, `SA-11 Buk LN/SR` | `MR SAM` | 40 |
| `Patriot str`, `S-300PS` radars | `LR SAM` | 40 |
| `M1097 Avenger`, `Strela-10M3`, `Tor 9A331`, `Osa 9A33 ln`, `2S6 Tunguska` | `SR SAM` | 25 |
| `Gepard`, `Vulcan`, `ZSU-23-4 Shilka` | `AAA` (and `SAM TR`) | 8 |

The groups the upgrades draw (`veaf-units.yaml`): Hawk = 6 radars, 1 command post, 9 launchers, 1 Avenger, 2-3 Vulcans, lorries; NASAMS = 1 radar, 1 command post, 4 launchers, 1 or 2 Avengers, lorries; Patriot = 1 radar, 4 command posts, 8 launchers, Vulcans, lorries; Avenger = 1 Avenger and a lorry; Gepard = 3 Gepards and a lorry.
With category prices alone, Hawk and NASAMS cannot cost the same (the Hawk holds more of every kind), and the Patriot reaches 5,000 only with a long-range radar at 600 points or more; the Avenger at 1,000 and the Gepard at 750 would put every red Strela, Tor and Shilka 5 to 6 times higher.

## Done (2026-11-20)

- `unitPrice` reads `SAM LL` as `sam_launcher` (15) and `SAM CC` as `sam_command` (10), after the `MR/LR SAM` and `SR SAM` checks: a launcher or a command post is no longer a gun.
- `veafCampaign.TYPE_PRICES`, a default price per DCS type for the SAM elements the attributes cannot tell apart, each with its reason in the code and in `PERSISTENT_CAMPAIGN.md`: Avenger 165, Gepard 41, Hawk radars 14 and launcher 5, NASAMS launchers 28, Patriot radar 93 and launcher 85, S-300 launchers 85 and radars 93. `resources.prices` still wins over it.
- The SA-11 needs no entry: its launcher and radar carry `MR SAM`. Red's Strela, Tor, Osa, Tunguska and Shilka keep 25 and 8.
- Ticket 02's hand prices (`price` on the NASAMS and Patriot upgrades) are gone: one rule, the spawn price, everywhere — the shop, the players' paid VEAF spawns, the AI's garrisons and reinforcements. `economy.prices` stays a campaign's override. The theatre dossier's guide gives the air defence upgrades' approximate prices; its `UPGRADE_PRICES` mirror is gone.
- Tests: the launcher and command-post categories, red's SHORAD and AAA unchanged, each `TYPE_PRICES` entry a real DCS type and overridable, no `price` left on an upgrade, and (simulator) the five upgrades drawn from the real groups within 10 % of Foothold's prices, median of 3 seeds.

The upgrades now, at 6 credits a point (8 draws):

| Upgrade | Price | Foothold |
|---|---|---|
| Hawk | 1,968 to 2,028 | 2,000 |
| NASAMS | 1,974 to 1,998, or 2,964 to 2,976 with a second Avenger (2 draws of 8) | 2,000 |
| Patriot | 4,962 to 5,058 | 5,000 |
| Avenger | 1,002 | 1,000 |
| Gepard | 750 | 750 |
| Infantry | 42 to 60 | 500 |
| Armour | 72 to 144 | 1,000 |

Infantry and armour are not brought to Foothold's: it would take a soldier at about 10 points and a tank or an IFV at about 40, 7 to 10 times today's, and red's garrisons, assault convoys and reinforcements are made of them. Red already cannot pay a SEAD from its first hour (ticket 04).

### The simulator (ticket 04), before and after

`campaign-sim report 9 3`, median of 3 seeds:

| Milestone | Before | After |
|---|---|---|
| average team, first CAP (`cheapest`) | 2 h 30 | 2 h 15 |
| average team, Hawk (saving) | 2 h 50 | 2 h 37 |
| average team, Patriot (saving) | 7 h 02 | 7 h 02 |
| red can no longer pay a SEAD | 1 h 00 | 1 h 00 |
| red stock, hour 3 / hour 9 (average, `never`) | 160 / 145 | 160 / 145 |

The guard's bounds (first CAP 1-3 h, Hawk 1 h 30-6 h, SEAD 45 min) still hold: not changed. Red's stock does not move on Oronte: none of its garrisons the players hit draws an S-300 or a Kub launcher, the only red types whose price changed.

## In-game check

1. F10 → Other → VEAF → Campaign → Shop → Zone upgrades → a zone: Hawk about 2,000, NASAMS about 2,000 (or 3,000), Patriot about 5,000, Avenger 1,000, Gepard 750.
2. A Patriot `-sam` spawn by a player (paid in credits): its message gives about the Patriot upgrade's price.
3. The Oronte campaign's `economy.prices.patriot: 5000` can go from its `campaign.yaml`: the spawn price is the same now.
