# 02 — a mission picks the airfields that deserve a channel

Status: ✅ done

392 airfields across the seven theatres, against the twenty-odd preset channels a DCS radio holds.
A mission cannot carry them all, so someone has to choose — and today nothing helps, which is how
two v6 missions ended up with a series nobody checked against DCS.

David, 2026-10-01: *lire la mission, lister les bases occupées, et (en demandant à un user de
décider, ou en fournissant l'outil à Claude via MCP) choisir les bases bleues (et rouges d'ailleurs)
qui méritent un canal et mettre à jour le plan de freq.*

## What it reads

The mission already says which airfields matter, and says it in more than one way:

- `warehouses` — which airfields a side holds, and `exclude_airports` for those it holds without
  offering slots;
- the player slots actually placed on each field, and the dynamic-slot links;
- FARPs and ships, which need a channel too and are not in the airfield reference at all.

An airfield a side holds **with slots** is the obvious candidate; one held without slots, or an
enemy field, is a judgement call — a SEAD mission may well want the tower of the field it is going
to strike. Hence a proposal, not an automatic verdict.

## Done when

- A command lists, for a mission folder, every airfield the mission uses, with side, whether it has
  slots, how many, and the frequencies the reference gives it — ranked, so the obvious ones come
  first and the budget is visible against the channel count.
- The choice can be made two ways, over the same code: a human at the CLI, and **an MCP action** so
  Claude can do it while authoring. The MCP action proposes and applies; it never silently decides
  what the mission author did not ask for.
- Applying writes the `bases` collection of `src/presets.yaml` with the **real** frequencies from
  the reference, keeps the hand-written tactical and flight channels untouched, and is idempotent.
- It refuses, with a message, to write a frequency that is not in the reference — that is the defect
  this whole lot comes from.
- Red fields are offered on the same footing as blue: *"et rouges d'ailleurs"*.
- Tested on the two real cases: Caucasus v6 (13 base channels, all wrong today) and GermanyCW v6
  (12, all wrong), each ending with the frequencies DCS shows on its F10 view.

## Open question for whoever takes this

Where does the channel **number** come from — the order in the collection, or a fixed map so that
channel 3 is the same field between two missions on the same theatre? The ten Foothold missions
share one plan and would answer this if their numbering is deliberate; worth reading before
choosing.

## Done (2026-10-01)

`presets_injector/airfield_channels_manager.py`, served by `veaf-tools content airfield-channels` and the
MCP actions `describe_airfield_channels` (read-only) / `set_airfield_channels`.

- **What it reads.** Side from `warehouses.airports[id].coalition`; dynamic slots as the build leaves them
  once `src/warehouses.yaml` is applied (declared side, `airports:` list, `exclude_airports`); parked
  player units by their group's first `airdromeId`, dynamic-slot templates excluded. Measured on both v6
  missions: their bases are known by their warehouses, not by parked slots (almost all slots start in the
  air or on a FARP/ship). FARPs and ships are not listed — no reference frequency to give them.
- **Channel number: the mission's `channel_lists`, untouched.** The command writes the `bases`
  collection only. An airfield already there keeps its alias (matched by DCS name, or by its first word
  when no other field of the theatre shares it — `Base-Krasnodar` is refused, two Krasnodar exist); a new
  one is aliased `Base-<DCS name>` (a bare name could be shadowed by a stale copy in the mission's `airports-*`); the written channels on no radio are reported for the author to place.
- Dry run on a provisional reference (from `Radio.lua`, scratch only): GermanyCW v6, 12 of 12 `Base-*`
  recognised; Caucasus v6, 11 of 13 (`Base-Krasnodar` ambiguous, `Base-MinVody` ≠ `Mineralnye Vody` —
  both reported as left untouched).
- **Run on the real reference (2026-10-01), on copies of both v6 missions** (their repositories untouched):
  GermanyCW 12 of 12 base channels rewritten with DCS's frequencies under their existing aliases;
  Caucasus 11 of 13, plus `Base-Krasnodar-Pashkovsky` / `Base-Mineralnye Vody` added and reported as on no
  radio, `Base-Krasnodar` / `Base-MinVody` reported as left untouched. A second run writes nothing.
- **Written as text, not through a YAML round trip.** ruamel rewrote ~40 lines of the GermanyCW file it
  had no business touching (`{ a }` → `{a}`) and its line endings; the rewrite now changes only the
  lines of the written entries — 42 lines on Caucasus, CRLF and flow style kept.
- **Fixing the two missions themselves belongs to their repositories.**
