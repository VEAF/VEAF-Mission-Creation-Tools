# 02 — Coalitions and countries — the reported case

Status: ✅ done

Type: docs · Files: `doc/mission-maker/build-messages/coalitions.md` + `.en.md`

## What it is

The page that would have answered the mission maker of `FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON`.

Messages: `validate.side_missing_countries`, `validate.side_without_country`,
`builder.coalition_placeholder_injected`, `builder.coalition_country_unexpected`.

## What it has to carry, beyond the message text

- **In Mission Editor terms.** The message names `coalition.red.country` and `coalitions.red`. The
  reader sees objects on a map and a coalition column in the editor. Two tables in the `.miz`
  describe the same fact — which countries a side owns, and what each of them fields — and the
  message fires when only the second is populated.
- **A country table.** The reader is handed a number. Since PR #966 the message names the country
  too, but the page is where the mapping lives, and where someone reading an older message, a log,
  or a `.miz` by hand can resolve an id.
- **What it is not.** The reported reader was convinced his **neutral statics** were the cause.
  They were not, and the reason is worth stating exactly, because half of it is counter-intuitive:
  statics *do* count as units for this check, but a neutral object belongs to the `neutrals` side,
  and the check runs per side. A message about `red` can only be about a red-side object.
- **The ways out, with the trade-off.** Assign the country to the side, or re-assign the objects to
  a country already listed — which is why the message prints both lists.
- **Where the fix happens.** Not in `mission.yaml`, which has no `coalitions` key — that was the
  assistant's exact mistake. It is the Mission Editor, or `src/mission/mission` in the folder.

## Definition of done

- [x] Both languages, in the `nav` with `nav_translations`
- [x] One explicit anchor per message, derived from its locale key
- [x] The country table is generated from the repository's own data, not typed by hand
- [x] The neutral-statics false lead is addressed head on
- [x] `poetry run docs-check` passes
