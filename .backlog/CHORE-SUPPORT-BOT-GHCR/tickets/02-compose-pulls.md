# 02 — The compose file names an image instead of a build

Status: ✅ done

Type: chore

## What

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

## Done when

- `docker compose config` resolves to the GHCR image with the `develop` tag by default;
- setting `VEAF_BOT_IMAGE_TAG=latest` in `.env` switches the channel with no edit to `compose.yml`;
- the two volumes, the secret, the restart policy and the log rotation are untouched.
