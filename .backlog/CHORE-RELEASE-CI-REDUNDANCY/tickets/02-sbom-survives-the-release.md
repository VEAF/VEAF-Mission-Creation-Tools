# 02 — the release keeps its SBOM

Status: ✅ done — 2026-11-05

`sbom.yml` attached `sbom.cyclonedx.json` to the release on the `published-v*` tag, and the release job's `veaf-build publish --force` then deleted and recreated that release: 6.35.0 and 6.36.0 have no SBOM.
Upload it from `release.yml`, after the publish step, onto the versioned release and `published-latest` (same prerelease guard as `veaf-logs.exe`), and drop the tag trigger and the attach step from `sbom.yml`.

## Acceptance

- `TestTheReleaseCarriesItsSbom` fails on the old workflows and passes on the new ones.
- On the next release, `gh release view published-v<x.y.z>` lists `sbom.cyclonedx.json` (not claimed before then).
