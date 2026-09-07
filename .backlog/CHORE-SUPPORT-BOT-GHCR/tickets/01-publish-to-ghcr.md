# 01 — CI builds the image and pushes it to GHCR

Status: ✅ done

Type: chore

## What

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

## The guard David asked for

The job must **fail rather than push** when the image carries a secret. Inspecting the built image,
not the build context: a `.dockerignore` reasons about what is offered, and the thing to prove is
what came out.

- no `.env` anywhere in the image;
- no `*.pem`, no `id_rsa`, nothing under `/run/secrets`;
- and the check itself has to be able to fail — a grep over an empty listing passes for the wrong
  reason, so the step asserts it finds the files it *should* find first.

## Done when

- a push to `develop` publishes both tags and the digest is visible on the package page;
- a pull request publishes nothing;
- an image built with a `.env` copied in fails the job.
