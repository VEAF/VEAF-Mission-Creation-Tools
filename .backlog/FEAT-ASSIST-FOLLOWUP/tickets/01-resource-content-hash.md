# 01 — Resource names should carry a content hash

Status: ✅ done
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

- [x] Decide and record the digest length; short enough to stay readable in `mapResource`.
- [x] `image_filename` includes the digest of the rendered bytes.
- [x] Confirm no orphan accumulates across two builds with different labels — assert it in a test.
- [x] `resource_key` and the Lua consumer stay paired.
- [x] Unit tests: same content → same name; one changed label → a different name for that state only.

## Acceptance criteria

- [x] Rebuilding after a label change produces a different file name for the affected state.
- [x] A second build with identical content produces identical names (no churn in the `.miz`).
- [x] No resource in the built `.miz` is unreferenced by `mapResource`.
- [x] `poetry run pytest` green; the checklist image tests updated rather than deleted.

## How to verify it actually fixes the trap

The unit tests cannot see DCS's cache. The real check is one flight: change a label, rebuild, fly
**without restarting DCS**, and confirm the corrected text appears. Worth asking David to fold into
whatever he flies next rather than making it a session of its own.

## Delivered — 2026-08-11

`image_filename(checklist_id, state, payload)` appends **8 hex characters** of a SHA-256 of the
rendered bytes — 32 bits, ample to tell one rendering of a state from another and short enough to
leave `mapResource` readable. `assist-f16c-cold-start-2-a465bc19.png`.

**The resource key deliberately carries no digest.** It is the stable handle the emitted Lua asks
`a_out_picture` for, so editing a label must not change the mission's scripts. A test pins that the
keys do not move when a label does.

### The design question, answered rather than assumed

The ticket said to verify whether a per-build name leaves orphans in the `.miz`, and not to assume.
Read end to end: **it does not, and for a precise reason.**

`write_miz` copies every file of the source archive that is *not* in `additional_files`
(`miz_tools.py`: `elif file_name in additional_files: pass` … `else: writestr(read(file_name))`). So a
changed name would indeed leave the old picture behind — **if the source archive contained one.** It
does not: `create_miz` rebuilds the `.miz` from `src/` on every build, and the images only enter
afterwards, through `write_miz`'s `additional_files`. Nothing from a previous build is in the archive
being copied.

Had the build written on top of its own output, this change would have earned back exactly the bug
`FIX-COMMUNITY-SOUNDS-PRUNED` repaired.

### One consequence that had to be fixed with it

`resources()` **rebuilt** each file name from the id and the state. A digest makes that impossible, and
leaving it would have made `mapResource` name files the archive does not contain — the editor prunes
what its resource table does not declare, which is that same bug from the other end. `ChecklistImages`
carries `file_names` per state now, and `resources()` pairs by index.

### Tests

7 new, and 4 existing ones updated because they hard-coded a name — each rerouted through
`file_names` so they pin the *text* or the *pairing* rather than the naming scheme. Notably
`test_state_ten_is_not_paired_with_state_one`, which guards the lexicographic trap ("-10" between
"-1" and "-2") and now asserts on the state prefix.

Coverage 80.42 % against a 79 gate — 1.42 points, inside the ~2-point band, so the ratchet does not
move. The mypy `ignore_errors` list holds only `luadata` (third-party), so nothing to erode there.

## Still open: the part no unit test can reach

The trap itself is DCS's cache, and no test here can see it. The real check is one flight: **change a
label, rebuild, and fly without restarting DCS** — the corrected text must appear. Worth folding into
whatever David flies next rather than making it a session of its own.
