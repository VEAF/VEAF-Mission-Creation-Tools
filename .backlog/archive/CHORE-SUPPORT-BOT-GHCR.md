# CHORE-SUPPORT-BOT-GHCR — the image is built once, in CI

Status: ✅ done — the three tickets are done; PR #932 merged 2026-09-07 · archived 2026-09-28

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
| 01 | [CI builds the image and pushes it to GHCR](CHORE-SUPPORT-BOT-GHCR.md) | chore |
| 02 | [The compose file names an image instead of a build](CHORE-SUPPORT-BOT-GHCR.md) | chore |
| 03 | [The host procedure, without a clone](CHORE-SUPPORT-BOT-GHCR.md) | docs |

## Definition of done

- A push to `develop` publishes `ghcr.io/veaf/veaf-support-bot:develop` and a `sha-` tag;
- a push to `master` publishes `:latest` and a `sha-` tag, so the channel exists the day a release
  happens;
- the publish job refuses to push an image carrying a `.env`, a key, or a mounted secret;
- `docker compose up -d` on the host needs no checkout of this repository;
- the README's procedure is the one an operator can follow with three files and no `git`.

---

## Tickets, in full

## 01 — CI builds the image and pushes it to GHCR

Status: ✅ done

Type: chore

### What

A `publish` job in `support-bot-ci.yml`, after `quality` and `container`, on a **push** only — never
on a pull request, where the token is read-only and where publishing a branch nobody reviewed would
be the point of the gate lost.

| Branch | Tags pushed |
|---|---|
| `develop` | `develop`, `sha-<short>` |
| `master` | `latest`, `sha-<short>` |

The `sha-` tag exists so a bad image can be rolled back by changing one line in `.env`, without
waiting for a fix to go through CI.

Authentication is the workflow's own `GITHUB_TOKEN` with `packages: write` — no personal access
token, nothing to rotate. The package is made **public once, by hand**, on its GitHub page; a
package created by a first push is private until somebody says otherwise, and a private one would
put a `docker login` on the Docker host.

### The guard David asked for

The job must **fail rather than push** when the image carries a secret. Inspecting the built image,
not the build context: a `.dockerignore` reasons about what is offered, and the thing to prove is
what came out.

- no `.env` anywhere in the image;
- no `*.pem`, no `id_rsa`, nothing under `/run/secrets`;
- and the check itself has to be able to fail — a grep over an empty listing passes for the wrong
  reason, so the step asserts it finds the files it *should* find first.

### Done when

- a push to `develop` publishes both tags and the digest is visible on the package page;
- a pull request publishes nothing;
- an image built with a `.env` copied in fails the job.

---

## 02 — The compose file names an image instead of a build

Status: ✅ done

Type: chore

### What

Replace `build: .` with `image: ghcr.io/veaf/veaf-support-bot:${VEAF_BOT_IMAGE_TAG:-develop}`.

Two consequences worth stating:

- **the host stops needing this repository.** `compose.yml`, `.env` and `github-app.pem` in a
  directory, and `docker compose up -d`. Updating becomes `docker compose pull && docker compose up -d`,
  which is also what makes a rollback a one-line edit;
- **`docker compose up --build` stops working there**, deliberately: there is no build context. The
  local build is still one command from a checkout, and the README says which.

`VEAF_BOT_IMAGE_TAG` carries **no** `SUPPORT_BOT_` prefix, and that is not cosmetic: `.env.example`
lists what the *Python* reads and `tests/test_packaging.py` asserts the two lists match in both
directions, so a variable belonging to the deployment rather than to the service would fail that
test. Same reason `VEAF_CLONE_URL` is named the way it is. Compose reads `./.env` for interpolation
on its own, so the operator sets it in the same file as everything else.

### Done when

- `docker compose config` resolves to the GHCR image with the `develop` tag by default;
- setting `VEAF_BOT_IMAGE_TAG=latest` in `.env` switches the channel with no edit to `compose.yml`;
- the two volumes, the secret, the restart policy and the log rotation are untouched.

---

## 03 — The host procedure, without a clone

Status: ✅ done

Type: docs

### What

`services/support-bot/README.md`, section *Where it runs*: the procedure becomes three files in a
directory and one command. It currently opens with `git clone https://github.com/VEAF/…`, which is
precisely what this lot removes.

- how to fetch `compose.yml` alone (`curl` on the raw URL) rather than cloning to get one file;
- what `VEAF_BOT_IMAGE_TAG` is for, and that `latest` becomes the right value once a release has
  been published from `master`;
- updating: `docker compose pull && docker compose up -d`;
- rolling back: set the `sha-` tag in `.env` and the same two commands;
- **the container still clones the repository on first start**, and that is not the thing this lot
  removed — `/bug` and `/suggest` need it. A reader who confuses the two will go looking for a
  defect when the first start takes a minute.

Keep the "why not the game server" and the private-key sections as they are.

### Done when

- the procedure can be followed on a host with Docker and no `git`;
- the CHANGELOG carries one entry under `[Unreleased]`.

---
