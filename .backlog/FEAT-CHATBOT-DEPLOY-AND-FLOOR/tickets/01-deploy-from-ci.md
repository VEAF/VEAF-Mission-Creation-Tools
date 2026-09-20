# 01 — The Worker deploys itself

Status: ✅ done

Type: feat · Files: `.github/workflows/chatbot-worker.yml`

## What it is

A push to `develop` that touches `poc/doc-chatbot/worker/**` deploys the Worker, after its unit
tests pass. Today the workflow gates the code and stops there, which is how #966 sat in the
repository, merged and green, while production ran the previous version.

## How

Extend the existing workflow rather than adding a second one: the tests are the gate the deploy
must wait on, and splitting them across two workflows means re-running the install to deploy.

- `deploy` job, `needs: worker-tests`, `if: github.ref == 'refs/heads/develop' && github.event_name == 'push'`
- `npx wrangler deploy`, with `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID`
- a `concurrency` group so two pushes cannot race a deploy

## The permission this needs, and what happens without it

The token is known to hold **KV edit**. **Workers Scripts edit** is a different permission and
nothing has needed it before. If it is missing the job fails on the deploy — which is right, and is
David's to widen; do not work around it.

## Do not repeat the index mistake

`wrangler deploy` has no local mode, so the silent no-op that cost six weeks is not available here.
A smoke probe after the deploy is still worth it: `POST /nope` must answer 404 and `POST /analyze`
403, which proves the Worker answers and routes. Say in the comment that this proves the Worker is
up, **not** which version it is — an honest narrow check beats a broad claim.

## Definition of done

- [x] A push to `develop` touching the Worker deploys it, after the tests
- [x] Nothing deploys from a pull request, or from any other branch
- [x] A smoke probe runs after the deploy, and its comment does not overstate what it proves
- [x] The hand-deploy instructions in `poc/doc-chatbot/README.md` say CI now does it
