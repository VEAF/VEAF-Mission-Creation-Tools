# Documentation images

Screenshots and diagrams referenced from the documentation pages.

## Layout

| Folder | Used by |
|--------|---------|
| `pilot/` | Pilot Guide (`doc/pilot/`) |
| `mission-maker/` | Mission Maker Guide (`doc/mission-maker/`) |
| `tools/` | CLI / tooling docs |

## Conventions

- Width ≥ 1280 px when possible.
- **PNG for a cropped detail, JPEG for a full map or cockpit shot.** The rule used to say PNG
  everywhere, and it is the wrong default for half of what goes in here: a DCS map is a terrain
  texture, so it is photographic and PNG buys nothing. Measured on the first four screenshots
  committed (the spotter-view walk-through, 1600 px wide): **6.0 MB as PNG against 1.1 MB as JPEG at
  quality 88**, for no visible difference. A cropped screenshot of flat UI colour is the other way
  round, so `spotter-view-shapes.png` stays a PNG.
- File names are lower-case, hyphen-separated, and match the placeholder paths
  already referenced in the Markdown (e.g. `pilot/f10-veaf-submenu.png`).
- Until a screenshot is captured, its placeholder reference renders as a broken
  image — this is expected during the documentation overhaul.
