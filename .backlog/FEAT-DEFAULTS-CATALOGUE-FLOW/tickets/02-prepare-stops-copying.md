# 02 — `prepare` stops laying down a full copy

Status: ✅ done

## Problem

`prepare` copies the whole `src/defaults/mission-folder/` tree, so a new mission folder receives a
351 KB duplicate of the dynamic-slot catalogue and a 286 KB duplicate of the spawnables. That copy
is what freezes: it is read by every later build and nothing ever refreshes it.

Once ticket 01 is in, the copy buys nothing — an absent file already means "use the shipped one".

## Work

- `prepare` writes the empty skeleton for the two aircraft catalogues instead of the full file.
- The skeleton carries a header comment saying what it means: empty = *I add nothing to the shipped
  catalogue*, not *I want nothing*; and pointing at the pull command of ticket 03.
- Existing folders are untouched — `prepare` already never overwrites without being told.

## Tests

- `prepare` on an empty folder → the two catalogues are the skeleton, and a build of that folder
  injects the shipped catalogue in full (the ticket 01 path).
- `prepare` on a folder that already has a populated catalogue → it is kept, as today.
