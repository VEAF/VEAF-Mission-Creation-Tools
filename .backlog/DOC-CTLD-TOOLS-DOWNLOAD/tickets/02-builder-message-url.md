# 02 — The builder's own message must not dead-end

Status: ✅ done

Type: docs · Files: `src/python/veaf-tools/veaf_libs/locales/{fr,en}.json`

## The defect

`builder.ctld_no_config` fires exactly when the reader needs the tool — CTLD enabled, no
`ctld-config.yaml` in the mission folder — and told them to "create one with ctld-tools" without
saying where to get it. The one message guaranteed to reach a reader who has not installed the tool
was the one that did not say where it lives.

## What ships

Both locales carry the releases URL **and** the pre-release trap in one sentence, because the URL
alone lands on a page whose landing view shows nothing:

> Create one with ctld-tools.exe, downloadable from https://github.com/VEAF/CTLD/releases
> (CTLD 2 releases are pre-releases: go through the Releases tab).

No behaviour change, no worker logic touched — so no mypy `ignore_errors` entry is reopened.

## Definition of done

- [x] `builder.ctld_no_config` carries the URL in `fr.json` and `en.json`
- [x] Both wordings say the same thing; neither leaves the reader on the landing page
