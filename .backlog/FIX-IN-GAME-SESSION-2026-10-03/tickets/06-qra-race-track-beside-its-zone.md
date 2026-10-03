# 06 — the QRA race-track sits beside its zone

Status: ✅ done — fixed by ticket 04, verified in game 2026-10-03
Type: fix

## Measured

*Ligne rouge d'At Tanf*, rebuilt from `develop` on 2026-10-03, QRA Sayqal triggered: the MiG-29S pair
flew 60 km from Sayqal to the edge of `QRA-Sayqal-Zone` (radius 35 km), intercepted, then flew legs
between **30 and 64 km** from the zone's centre — a race-track of about 35 km (19 NM), as
`zone_defense` intends, but lying on the far side of the zone rather than across it.

## To find out

How `zone_defense` places its two turn points from the group's position and the zone: centred on the
zone, or starting from where the group enters it.

## Read (2026-10-03, afternoon)

`zone_defense` places its turn points **centred** on the zone: `wp2` and `wp3` are the centre minus
and plus half a leg along the approach axis (`veafAircraftSpawn.lua`), and `QRA-Sayqal-Zone` is a
circle with its easting in `y` (read in the `.miz`). A race-track 30 to 64 km from the centre is not
what the route says.

The likely cause is ticket 04: an `EngageUnit` left on the queue for a target outside the zone kept
the CAP chasing it, and the cleanup could pop the route itself. Ticket 04 now hands the patrol back
when the targets change or the CAP leaves its zone. To measure again in game, positions every ten
seconds, before calling this one fixed.

## Verified in game (2026-10-03, second pass)

The Sayqal pair crossed its zone and turned back at 21 km (half a 20 NM leg, plus the turn) — the
race-track centred. Then an intercept: the pair chased out to 40 km while engaging, and once the target
was gone the watchdog handed the patrol back; the leader flew back in and passed **0.1 km** from the
zone's centre. This morning it kept circling 30 to 64 km out.
