# 01 — Mirror veaf-logs onto `published-latest`, and sweep every asset

Status: ✅ done

## What was wrong

`.github/workflows/release.yml`, step *Upload veaf-logs to the release*, uploaded to the versioned
tag only:

```bash
gh release upload "${{ steps.version.outputs.tag }}" "dist/veaf-logs.exe#..." --clobber
```

The two assets added to the workflow before it — the map-capture kit (step *Upload the kit to the
release*) and the cross-platform standalone binaries — each follow their versioned upload with a
mirror onto `published-latest`, guarded so a pre-release leaves the stable assets alone. This step
did not.

## What was done

1. The same mirror, with the same guard, appended to the veaf-logs step.
2. `test/python/test_release_mirrors_every_asset.py` — four tests:
   - the workflow still uploads to both kinds of release (a guard on the module's own assumption);
   - veaf-logs specifically reaches `published-latest`;
   - **every** asset uploaded to a versioned release is also uploaded to `published-latest` — the
     sweep, so the next asset added cannot repeat this;
   - each mirror carries a pre-release guard.
3. 6.18.0 repaired by hand: `veaf-logs.exe` downloaded from `published-v6.18.0` and uploaded to
   `published-latest`, then re-downloaded from `published-latest` to prove it — HTTP 200,
   40 256 564 bytes, identical size.

## Proof the tests fail on the previous workflow

Ran against `origin/develop`'s copy of `release.yml`:

```
FAILED test_veaf_logs_reaches_the_latest_release
FAILED test_every_asset_uploaded_to_the_version_tag_is_mirrored
```

The other two passed before as they pass now: they assert invariants that were already true (both
kinds of upload exist; every mirror is guarded). They are guards on the test module itself, not
regression tests — and the first one earned its place immediately, catching a pattern of mine that
captured `"${{` instead of the upload target.

## Why the workflow is read as text

The upload commands live inside `run:` shell blocks. Parsing the YAML yields one long string per
step and nothing structural to assert on, so the pairing is matched on the command text. The limit
is stated in the PRD: this proves the mirror is *written*, not that it *runs*. Only a release proves
that, and 6.18.0's manual repair shows the command itself is sound.
