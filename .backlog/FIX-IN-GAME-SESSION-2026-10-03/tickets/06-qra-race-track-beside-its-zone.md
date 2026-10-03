# 06 — the QRA race-track sits beside its zone

Status: ⬜ ready
Type: fix

## Measured

*Ligne rouge d'At Tanf*, rebuilt from `develop` on 2026-10-03, QRA Sayqal triggered: the MiG-29S pair
flew 60 km from Sayqal to the edge of `QRA-Sayqal-Zone` (radius 35 km), intercepted, then flew legs
between **30 and 64 km** from the zone's centre — a race-track of about 35 km (19 NM), as
`zone_defense` intends, but lying on the far side of the zone rather than across it.

## To find out

How `zone_defense` places its two turn points from the group's position and the zone: centred on the
zone, or starting from where the group enters it.
