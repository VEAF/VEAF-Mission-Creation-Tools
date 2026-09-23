# FEAT-DEFAULTS-CATALOGUE-FLOW — a shipped catalogue that never reaches an existing mission

Status: 🔄 in-progress

Opened 2026-09-22, alongside [`FIX-DYNSLOT-WIRING`](../FIX-DYNSLOT-WIRING/PRD.md) and sequenced
after it. Where that lot fixes the wiring, this one fixes how a catalogue is **produced** and how it
**reaches** a mission.

## Measured

`prepare` copies `src/defaults/mission-folder/` into the mission folder, and never replaces an
existing file without being told to. So `src/dynamic-slot-templates.yaml` is a **full 351 KB
duplicate**, frozen on the day the folder was created. A new folder prepared today gets all 128
templates; a folder prepared in June keeps its 104 and will keep them forever.

The `F-14BU Template` entered the catalogue on 2026-09-21 (`b03ac841`) and shipped in v6.24.0, tagged
the same evening. A mission maker who updates the tool still does not get it, because the tool is not
where his catalogue lives. That is the shape of the report this investigation started from.

Two mission folders on this machine already show the drift: `VEAF-Demo-Mission` and
`VEAF-Open-Training-Mission-Caucasus` both carry a 62-byte empty placeholder while the shipped
catalogue is 351 KB.

## Decision

David, 2026-09-22, in two steps — the second corrects the first:

- the shipped catalogue is used automatically when the mission folder has **no file, or an empty
  one** (a new mission, or one that never configured this);
- when the maker **has** a file, it stands alone. Nothing is merged behind his back;
- and he gets an explicit, **selective** way to pull in what the shipped catalogue has and he does
  not — entry by entry, never overwriting one he already owns. *"il faut un moyen pour le Mission
  Maker de reprendre les nouveaux defaults — mais de manière sélective, pas brutalement tous les
  defaults."*

This is the ADR 0005 model (framework data in `published.zip`, per-mission file as a delta) with one
deliberate difference: the merge is **not** automatic, and the existing entry wins.

## Scope

| # | ticket | |
|---|---|---|
| 01 | [Use the shipped catalogue when the mission file is absent or empty](tickets/01-shipped-catalogue-as-fallback.md) | |
| 02 | [`prepare` stops laying down a full copy](tickets/02-prepare-stops-copying.md) | |
| 03 | [A selective pull command](tickets/03-selective-pull-command.md) | |

## Definition of done

- A mission folder with no aircraft catalogue builds with the shipped one, and the build says which
  it used.
- A mission folder with its own catalogue builds exactly as it does today.
- A maker can list what the shipped catalogue has that he does not, and take named entries or all
  the missing ones, with his own entries untouched.
- Documentation in both languages, `nav` entries included, and `docs-check` green.
