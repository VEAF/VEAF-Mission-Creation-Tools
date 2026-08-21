# 03 — Advance, hold and stop, as three visibly different things

Status: ✅ done
Type: feat

David's arbitration, and the part he was explicit about: `hold until further orders` **finishes the
current leg and parks at the next point**; `stop` **halts where it stands**. *"`hold` paces a mission,
`stop` rescues one going wrong; naming them alike would make the useful one unusable."*

## What exists

The F10 menu already offers two convoy commands (`veafSpawnCore.lua:947-949`):

| Menu | Function | Effect |
|---|---|---|
| `menu.spawn.convoy_stop` | `stopClosestConvoy` | pushes a `Hold` task — halts where it stands |
| `menu.spawn.convoy_move` | `moveClosestConvoy` | re-issues the route — resumes after a stop |

So `stop` and *resume* exist. What is missing is **advance now** and **hold at next point**, and the
wording that keeps `hold` and `stop` apart on screen.

## What this ticket does

- **advance now** — start the next leg without waiting for arrival
- **hold until further orders** — let the current leg finish, then stay put at that point
- keep **stop** (immediate) and **resume**, renamed so no two entries read alike
- every command reports what it did to the player, naming the point where relevant, so the two are
  distinguishable from the cockpit and not only in the code

## Definition of done

- [x] Four commands, each with its own message: advance, hold, stop, resume
- [x] `hold` at the last point of an itinerary says so rather than silently doing nothing
- [x] `stop` then `resume` still works, unchanged
- [x] i18n keys in both languages, menu labels included
- [x] Lua tests over each transition, including the ones that must be refused
