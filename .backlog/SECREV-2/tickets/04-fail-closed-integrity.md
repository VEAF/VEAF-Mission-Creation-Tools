# 04 — Integrity checks that pass when their metadata is missing

Status: ⬜ ready
Type: fix
Findings: VMR-011 🟡, VMR-009 🟡, plus the bridge/updater fetch findings

## The pattern

A verification that is skipped when the material it needs is absent verifies nothing, while reading
as though it does. The review found three shapes of it:

- **VMR-011** — the updater's checksum verification **passes** when release metadata is missing or
  malformed. An attacker who can influence the metadata does not need to break the checksum; they need
  to remove it.
- **VMR-009** — `read_miz` / `write_miz` decompress untrusted `.miz` members with no size cap. A small
  archive can expand to fill a disk.
- The dcs-bridge and updater download and execute remote payloads with no size cap and no integrity
  check.

## The fix

Fail **closed**: absent integrity material is a failure, not a pass. Cap every fetch and every
decompression, and verify what was fetched before using it.

- [ ] Updater: no checksum, or an unparseable one, means refuse — with a message saying which.
- [ ] `read_miz`: a total-uncompressed-size cap and a per-member cap, both refusing rather than
      truncating. `safe_zip.py` already exists and the review calls the Python ZIP path well-hardened,
      so check whether this is a matter of routing `.miz` through it rather than new code.
- [ ] Cap and verify the bridge and updater downloads.
- [ ] Tests for each: missing metadata, malformed metadata, an over-cap archive.

## A caution on the updater

It updates the tool on a mission maker's machine. A change that makes it refuse more readily can strand
someone on an old version with an unhelpful message. Every new refusal needs to say what is wrong and
what to do — and it is worth checking what happens on the very next release after this ships, since a
fail-closed updater that is wrong about its own metadata format cannot update itself out of the problem.
