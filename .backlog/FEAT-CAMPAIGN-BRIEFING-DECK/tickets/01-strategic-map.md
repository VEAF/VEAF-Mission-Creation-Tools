# 01 — The strategic map, rendered from the campaign

Status: ✅ done

A PNG of the campaign's ground, rendered from `campaign.yaml` and the campaign state: each zone as a circle at its radius in its owner's colour, its display name (ticket 03), the axes between zones, a scale in km and nm, the OpenStreetMap credit.
Airfield positions come from `veaf_libs/data/airdrome-positions.yaml`, never from memory; the prototype read them there.

- **The base layer is shared** with [`FEAT-BRIEFING-MAP`](../../FEAT-BRIEFING-MAP/PRD.md) ticket 01: tile download, local cache, an identifying `User-Agent` that names the tool by its URL and **never carries personal data**, the credit. Build it in `veaf_libs`, once.
- No network, or a tile refused: the map still renders, on a plain background, and says so.
- The legend speaks to pilots: "tenu par les bleus / les rouges, neutre, axes de progression" — not how a zone is taken (David: "moins de trucs techniques", quoting "Le cercle est la zone à tenir pour la prendre").
- The same picture can go into the DCS briefing of the mission through `set_briefing_picture`, which exists.

## Done when

Tests render a fixture campaign from cached tiles (no network in tests): the zones fall at the right pixels for their lat/lon, colours follow the state's owners, the render works without tiles; and the `User-Agent` is asserted free of anything but the tool's name and URL.
