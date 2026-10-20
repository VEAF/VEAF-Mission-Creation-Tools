# 04 — sweep the missing theatres and publish the release

Status: 🧑 waiting-human

David runs DCS: `veaf-tools dcs terrain-sweep` for Caucasus, then GermanyCW, MarianaIslands, MarianaIslandsWWII, TheChannel and Afghanistan if his licences open them (Kola and Iraq are not installed on his PC).

Publishing is an outward action: the asset list and sizes are shown, and the release goes out on David's explicit go.

## Done when

- The `terrain-data` release holds at least the five existing grids, and Caucasus once swept.
- `gh api repos/VEAF/VEAF-Mission-Creation-Tools/releases/latest` still answers the tools' release.
- `describe_terrain` answers on a PC with no local grid.
