# 03 — The host procedure, without a clone

Status: ✅ done

Type: docs

## What

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

## Done when

- the procedure can be followed on a host with Docker and no `git`;
- the CHANGELOG carries one entry under `[Unreleased]`.
