# 04 — Integrity checks that pass when their metadata is missing

Status: ✅ done — all three shapes refuse: VMR-011 (updater metadata), VMR-009 (archive members), and the network download cap (2026-08-11)
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

- [x] **Updater fails closed (VMR-011)**. There were **four** fall-through paths, not the two the
      finding described: no metadata asset, an undownloadable one, unparseable JSON, and a missing
      checksum key — each warned and installed anyway. All four refuse now, extracted into
      `_checksum_verified` so they are unit-testable without driving the whole download flow.
- [x] **`read_miz` reads under a cap (VMR-009)**. The answer to the ticket's question: **new code,
      not routing**. `safe_zip.py` does exist and `miz_tools` already imports `safe_extract_all`,
      but that guards *extraction to disk*; `read_file_in_archive` pulls members straight into
      memory with a bare `.read()`, which no on-disk cap can bound. Added `safe_read_member`
      alongside it — declared size checked first (cheap), real stream counted while reading (what
      actually holds).
- [x] **Cap and verify the bridge and updater downloads.** Both halves are in, and they landed in
      different lots, which is why this line stayed open longer than it should have. The *verify*
      half came with `SECREV-2` ticket 07: the bridge fetch is capped at 2 MiB (VMR-034, measured
      against its real 13 237 bytes) and every hop of a release-asset download must be https on a
      GitHub host (VMR-037) — a fix whose first version had the very hole it was closing, since
      `requests` follows redirects anywhere by default. The *cap* half is this pass:
      `download_asset` streamed nothing and read `response.content` whole, so a reply with no
      `Content-Length` that never ends had no bound at all — on an updater that installs and then
      **runs** what it downloads. It now reads in 64 KiB chunks against `_MAX_ASSET_BYTES` = 256 MiB,
      a bound chosen from measurement (largest real asset: `published.zip` at 61 MiB) and matching
      `safe_zip.MAX_MEMBER_UNCOMPRESSED_BYTES` so the two agree. 5 tests, including an endless
      response and both sides of the boundary.
- [x] Tests for each delivered part: 5 for the member cap, 12 for the updater — including that a
      *good* release still installs, which is the failure mode that would strand people.

## A caution on the updater

It updates the tool on a mission maker's machine. A change that makes it refuse more readily can strand
someone on an old version with an unhelpful message. Every new refusal needs to say what is wrong and
what to do — and it is worth checking what happens on the very next release after this ships, since a
fail-closed updater that is wrong about its own metadata format cannot update itself out of the problem.

## Acceptance criteria

- [x] All three shapes refuse, each with a missing-case and a malformed-case test.
- [x] `read_miz` caps per member, refusing rather than truncating. Decision recorded: new code
      (`safe_read_member`), because `safe_extract_all` guards the disk and this path never touches it.
- [x] Every refusal names the escape hatch `--no-verify-checksum`, asserted by a test that reads
      each message in **both** locales rather than trusting that they were written.
- [x] **The publish side had to be hardened in the same breath**, and this is the criterion that
      nearly got missed. `veaf-build` produces `published-metadata.json` with `published_zip_sha256`
      — the exact name and key the updater expects, verified — but it had **two silent failure
      paths**: `worker.py` warned and continued when the file could not be written, and `github.py`
      skipped the upload if the file was absent *and* ignored the upload's own return code. With a
      fail-closed updater, either one publishes a release nobody can install, discovered by a user
      rather than by us. Both are errors now.
