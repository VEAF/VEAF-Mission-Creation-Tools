# 04 — An assault convoy strong enough to fight presses on to its target zone

Status: ✅ done

Measured live on *Kolkhida* mission 1 through the fiddle hook (read-only), mission time 07:45: the red assault convoy `Senaki - Poti assault` is in groundAI state 3 (fighting). Its 7 armed vehicles (ZTZ96B ×2, BMP-2, Chieftain_mk3, CHAP_T90M, Tigr_233036, BMP-3) are stopped (speed 0.0) 2761–2940 m from Poti's centre. Its nearest threats (Poti's garrison: LAV-25, Strykers, Marder; the blue convoy's VAB Mephisto) are 1706–1815 m away. It has 18 recent threats and its last contact is 0 s old: contact never ends, because Poti holds the 24-unit blue garrison and the blue convoy, always in sight.

Cause, from the code: `ConvoyUnitHandler:fight` (`veafGroundAI.lua`) drives to `ASSAULT_STANDOFF` (900 m) of the threat of the moment, or holds; `standDown` and `resume` only come after `QUIET_DELAY` without contact, so a convoy in permanent contact never resumes its route to the zone.

- An assault convoy (one the campaign sent, with a target zone) that `convoyShouldFight` judges strong enough keeps moving toward its target zone while engaging. A plain convoy keeps today's behaviour; a weaker one still falls back.
- Lua tests: an assault convoy in permanent contact but stronger keeps closing on its target zone and ends inside it; a weaker one falls back; a non-assault convoy is unchanged.
- `veafGroundAI.md` / `CAMPAIGN.md` (FR + EN).
