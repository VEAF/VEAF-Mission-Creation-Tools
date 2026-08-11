# 01 — Resource names should carry a content hash

Status: ⬜ ready
Type: fix

## The trap, as it was actually hit

**DCS caches embedded resources by name.** During the first checklist flight, the on-screen image for
state 0 showed raw i18n keys while every later state was correctly translated.

The `.miz` was innocent — all seven embedded PNGs matched a fresh render byte-for-byte. State 0 was
simply the only one that had already been *displayed* under an earlier, untranslated build, so DCS
served its cached bitmap. **A full DCS restart cleared it.**

Two things make this worth preventing rather than documenting:

- The symptom points nowhere near the cause. "The text is wrong, but only on the first image" reads
  as a translation bug or a generator bug. It cost an evening.
- It hits **any mission maker iterating on a checklist**, not just whoever wrote the engine. Change a
  label, rebuild, fly: the step you already looked at keeps its old picture.

## The fix

`veaf_libs/checklist_images.py:118` builds the name from the checklist id and the state only:

```python
def image_filename(checklist_id: str, state: int) -> str:
    return f"assist-{checklist_id}-{state}.png"
```

Mix a short digest of the PNG bytes into it, so different content is never the same name and DCS
cannot serve a stale bitmap.

## Decide before implementing

**Does a changing name leave dead resources in the `.miz`?** `render_all` returns the full
`{name: bytes}` set per build and the builder collects it into `self.checklist_images` — so if the
archive is written from that set each time, nothing accumulates. Verify it rather than assume: an
orphan resource in `mapResource` is exactly the shape `FIX-COMMUNITY-SOUNDS-PRUNED` had to repair,
and adding a per-build name would be a bad way to earn that bug back.

Also check both consumers move together: `resource_key()` (line 100) and the Lua side that asks
`a_out_picture` for the resource. A hash in the file name but not in the key, or vice versa, breaks
the pairing the `resources()` mapping maintains.

## Tasks

- [ ] Decide and record the digest length; short enough to stay readable in `mapResource`.
- [ ] `image_filename` includes the digest of the rendered bytes.
- [ ] Confirm no orphan accumulates across two builds with different labels — assert it in a test.
- [ ] `resource_key` and the Lua consumer stay paired.
- [ ] Unit tests: same content → same name; one changed label → a different name for that state only.

## Acceptance criteria

- [ ] Rebuilding after a label change produces a different file name for the affected state.
- [ ] A second build with identical content produces identical names (no churn in the `.miz`).
- [ ] No resource in the built `.miz` is unreferenced by `mapResource`.
- [ ] `poetry run pytest` green; the checklist image tests updated rather than deleted.

## How to verify it actually fixes the trap

The unit tests cannot see DCS's cache. The real check is one flight: change a label, rebuild, fly
**without restarting DCS**, and confirm the corrected text appears. Worth asking David to fold into
whatever he flies next rather than making it a session of its own.
