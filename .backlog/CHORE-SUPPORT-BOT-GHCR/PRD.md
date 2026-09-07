# CHORE-SUPPORT-BOT-GHCR — the image is built once, in CI

Status: 🔄 in-progress — the three tickets are done; the PR is open

Origin: David, 2026-09-07, the evening the bot went up. *"On va construire l'image docker du bot dans
un CI (et déposer sur ghcr) — attention à ce qu'elle n'emporte aucun secret. Ensuite le
docker-compose sur le serveur référencera l'image, et utilisera le .env pour les secrets."*

## What it changes, and what it does not

**It changes:** the Docker host no longer clones this repository. Today `compose.yml` carries
`build: .`, so bringing the bot up means a full clone of VMCT — the tools, the documentation, the
Lua, the missions — on a machine that runs a Python service needing none of it. From here the host
holds three files in a directory of its own: `compose.yml`, `.env` and `github-app.pem`.

**It does not change:** the clone *inside* the container. `/bug` and `/suggest` read the repository
to turn a stack trace into a file and a line, and the entry point creates that clone on first start
— shallow, single-branch, 87 MiB measured, on its own volume. The host clone was for **building**;
the container clone is the product. Worth stating plainly, because "we removed the clone" would be
read as both.

## Decisions taken with David, 2026-09-07

| # | Decision | Why not the other one |
|---|---|---|
| Visibility | **Public package** | The image carries only code that is already public. Private would mean a `docker login ghcr.io` and a personal access token living on the host — one more secret to place and rotate, to protect what anyone can already read on GitHub |
| The App's key | **Still a file**, mounted as a compose secret | Inline in `.env` is one file fewer and puts the heaviest secret — it writes to a public repository — into `docker inspect` and into the container's config on disk |
| The tag | **`develop` now, `latest` after a release**, chosen in `.env` | Asked as a question and it is worth the answer: `latest` is published from `master`, and nothing has been released from `master` since the bot exists, so a compose pinned to `latest` today would find no image at all. The tag therefore comes from `VEAF_BOT_IMAGE_TAG`, defaulting to `develop`: switching channels is one line in `.env`, not an edit of `compose.yml` |

## The thing to be careful about, since David named it

**No secret may enter the image.** Three guards, and only the third is new:

1. `.dockerignore` excludes `.env`, and `tests/test_packaging.py` asserts that it does;
2. the CI build context is a fresh `actions/checkout`, which holds no `.env` and no `.pem` — they
   only ever exist on David's workstation and on the Docker host;
3. **new here:** the publish job inspects the image it is about to push and fails on a `.env`, a
   `*.pem`, or anything under `/run/secrets`. A guard that only reasons about the build context
   would not catch a future `COPY` that reaches for one.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [CI builds the image and pushes it to GHCR](tickets/01-publish-to-ghcr.md) | chore |
| 02 | [The compose file names an image instead of a build](tickets/02-compose-pulls.md) | chore |
| 03 | [The host procedure, without a clone](tickets/03-docs.md) | docs |

## Definition of done

- A push to `develop` publishes `ghcr.io/veaf/veaf-support-bot:develop` and a `sha-` tag;
- a push to `master` publishes `:latest` and a `sha-` tag, so the channel exists the day a release
  happens;
- the publish job refuses to push an image carrying a `.env`, a key, or a mounted secret;
- `docker compose up -d` on the host needs no checkout of this repository;
- the README's procedure is the one an operator can follow with three files and no `git`.
