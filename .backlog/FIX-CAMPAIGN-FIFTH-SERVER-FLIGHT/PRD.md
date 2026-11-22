# FIX-CAMPAIGN-FIFTH-SERVER-FLIGHT — what the 22/11 afternoon on the Campagne server showed

Status: 🧑 waiting-human — the in-game checks, and ticket 02's measure in DCS

The persistent campaign "Bouclier de l'Oronte" (Northern Syria, `foothold2_server`), flown on 2026-11-22 in the afternoon, after the 22/11 redeploy. David's four remarks, each read in the server's `dcs.log` and the code (2026-11-22).

## Read (2026-11-22)

1. **The red CAS Su-25 go after the AWACS.** Logged that afternoon: `red cas Abu al-Duhur 2 #2 (Su-25) kills AWACS Magic-1`, then `kills Hatay_F-16CM bl.50_20-1`. The Su-25 carries two R-60M (`dynamic_settings.py` line 34, `FAB-250*4,UB-13*2,R-60M*2,Fuel*2`), and the strike route sets ROE weapon free (`veafCampaignOps.lua` line 992, `Option name 0 value 0`): the AI engages anything it detects, aircraft included.
2. **Hatay's radar air defence never fires.** Kills by unit type in the log since 2026-11-18: Hawk 0 — Hatay's nine `Hawk ln` still hold their 27 missiles in every `[CAMPAIGN AIRDEF]` line —; Avenger 5, Gepard 5, Roland ADS 4, Linebacker 1, all self-contained vehicles; NASAMS 6, from Menagh's upgrade, **a group of its own**. The Hawk site is laid out tight (every launcher within 800 m of its radars, read from the save). A zone's garrison is **one DCS group** of 30 to 40 units ("Aleppo: 40 unit(s), 1 group(s)"). Hypothesis, not measured: a SAM made of separate radars and launchers does not work inside a large mixed group. If so, the SA-11 / SA-6 / SA-3 batteries `medium_range_sam` added to Aleppo and Bassel Al-Assad on 2026-11-22 (FEAT-CAMPAIGN-AIR-DEFENCE-VARIETY) are silent too.
3. **The AWACS holds too near the front, perhaps beside a red zone.** `veafSupport.station` walks from the nearest red zone towards the asset's Mission Editor orbit and stops at the first point `margin` (30 km) beyond every red zone's SAM reach, never nearer than the side's own front (`veafCampaignOps.supportFront`). A red zone with only MANPADS (Jisr al-Shughur, reach 4 km) puts the AWACS some 35 km from it. The axis comes from the nearest threat only. The AWACS's actual position was not logged, so "on the red side" is David's observation, not a measure. David: its radar sees about 100 NM, it has no need to be that close; the tankers are handy near the front.
4. **A Mi-8 vanished on its way and another was sent on the same route.** `helicopter_timeout` is 1200 s (`veafCampaign.lua` line 96); past it, `followHelicopter` (`veafCampaignOps.lua` line 644) calls `finish(record, "failed")`, which destroys the helicopter, and the next dispatch sends another in the same second. The Mi-8 flies at `veafAircraftSpawn.HELICOPTER_SPEED` = 40 m/s: Bassel Al-Assad → Jisr al-Shughur is 57 km, about 24 min of flight. On 2026-11-22, 3 supply helicopters out of 3 were removed this way (Jisr at 15:39 and 15:59 UTC, Abu al-Duhur from Al-Safira at 16:39 UTC), 45 points of red's stock lost.

## Decided

David, 2026-11-22: one lot, four tickets, the recommendations below. The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket | Status |
|---|---|---|
| 01 | [Red strikes engage only their targets](tickets/01-strikes-engage-only-their-targets.md) | 🧑 |
| 02 | [A garrison's SAM in a group of its own](tickets/02-garrison-sam-in-its-own-group.md) | 🧑 |
| 03 | [The AWACS holds well behind the front](tickets/03-awacs-holds-behind-the-front.md) | 🧑 |
| 04 | [A supply helicopter's timeout from its distance](tickets/04-helicopter-timeout-from-distance.md) | 🧑 |

## State (2026-11-22)

| # | Left to do |
|---|---|
| 01 | in-game check: ROE OPEN_FIRE (2) on a strike's first point and a SEAD's push point |
| 02 | Measured 2026-11-22 evening: the Hawk never fires, in Hatay's mixed group, in a group of its own, or as a standard site alone, while a NASAMS beside it fires at the same armed Su-25. The mixed-group hypothesis is refuted; no split. But the Campagne server log has a garrison Hawk firing two MIM-23K at a Su-25 on 2026-11-20, and red SEAD killing blue Hawk radars repeatedly: read the next flight before any change |
| 03 | in-game check: `awacs_standoff` (100 km) for an AWACS, tankers unchanged; each move logged from the bullseye |
| 04 | in-game check: a helicopter's own timeout: distance / 40 m/s × 1.5 + 300 s, floored at `helicopter_timeout` |
