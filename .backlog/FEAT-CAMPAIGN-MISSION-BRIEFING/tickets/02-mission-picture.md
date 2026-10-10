# 02 — What the built mission says: flights, support, carrier, QRA, airfields

Status: ✅ done

The briefing states what the squadron will find in the mission, read from the **built** `.miz` (after presets and the rest of the pipeline), never typed:

- client flights: name, callsign, type, count, base (airfield, or the carrier for a deck start); **dynamic-slot templates excluded** (`dynSpawnTemplate = true`);
- the airfields of the players' side offering dynamic slots, with their UHF/VHF/FM and TACAN (`describe_airfield_channels`);
- support: AWACS and tankers by task, each once, with frequency and TACAN from its `ActivateBeacon`; the carrier's tower (VHF), TACAN, ICLS, Link 4; the deck tanker;
- the QRA zones the mission declares (an alert, said as intelligence: type and strength unconfirmed);
- date, time, weather (wind said FROM, as pilots read it: DCS stores where it blows to), QNH, bullseye.

## Done when

Tests read a fixture `.miz` and get the flights without the templates, each support aircraft once, the carrier tower in VHF, the wind from its true direction.
