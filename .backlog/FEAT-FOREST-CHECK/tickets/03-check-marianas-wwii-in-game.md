# 03 — Check the Marianas WWII forests in game

Status: ✅ done

On every map but one, `forest-check` put none or almost none of the parking stands VMCT ships in a forest (0 to 2.3%, against 3 to 36% for the same stands moved 3 km).
On MarianaIslandsWWII it put 164 of 534 in a forest, most of them on three airfields, measured on 2026-11-16: Agana 39 of 39, Orote 34 of 35, Airfield 3 57 of 83.

The stand numbers of `data/parking/*.json` are DCS's terminal ids, one more than the Mission Editor's label (Agana: 2 to 40 in the file, 01 to 39 in the editor); its entries of type 16 are runway points, not stands.

## Result (David, 2026-11-16)

F10 view in "Map" and "Sat" modes on Agana: the whole clearing around the runway, stands 01 to 39, is open ground, bare on the Sat view.
So the reader was wrong on that map. The cause, measured on Agana's stand 39 (-811, -1606): on the Marianas the forest is a ground texture (`Splatmap5.1` / `Forest`, draw order 49), and the airfield (`SplatmapUnique5.1` / `Runway`, draw order 103) is drawn over it; the reader looked at the forest alone. Fixed by ticket 04.
