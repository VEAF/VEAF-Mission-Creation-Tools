# 01 — The image can refresh its own clone

Status: ⬜ ready

Type: fix

## What to build

`git` in the image, and an entry point that clones the repository into the checkout volume the first
time it starts.

- `apt-get install --no-install-recommends git`, in the same layer as its cache cleanup.
- An entry point that clones **only when the volume holds no `.git`**, then `exec`s the module. A
  container restarted a hundred times clones once.
- A shallow clone (`--depth 1`, single branch): the service reads files, never history. The
  refresh — `git fetch --quiet --prune <remote> <branch>` then `git reset --hard` — works on a
  shallow clone and keeps it shallow.
- The clone URL comes from `VEAF_CLONE_URL`, **outside** the `SUPPORT_BOT_` prefix, defaulting to
  the public repository. That name is deliberate: `.env.example` may only hold `SUPPORT_BOT_*`
  variables the Python reads, and `tests/test_packaging.py` asserts that in both directions. This
  one belongs to the image, not to the service.

## `exec`, not a shell that lingers

The current entry point is exec form on purpose, so `docker stop` sends `SIGTERM` to Python itself
and the clean shutdown runs. A wrapper script must end with `exec python -m veaf_support_bot "$@"`;
without `exec`, the shell keeps PID 1, swallows the signal, and Docker kills the service at ten
seconds — losing whatever was mid-exchange.

## The test that would have caught this

A static check that the Dockerfile installs `git` is worth little; what settles it is asking the
built image:

```bash
docker run --rm --entrypoint git veaf-support-bot:ci --version
```

The `container` CI job builds the image already, so this is one more step there. Add with it a run
that mounts a real clone and asserts the service **publishes** `/bug` — the shape of hole this lot
exists to close is a command silently absent, which every current test tolerates.

## Definition of done

- [ ] `git` present in the image, verified by running it in the built image in CI
- [ ] Entry point clones once into an empty checkout volume, and never again
- [ ] Shallow, single-branch clone; the refresh still works against it
- [ ] `exec` preserved, so `SIGTERM` still reaches Python
- [ ] `VEAF_CLONE_URL` documented where the deployment is documented, not in `.env.example`
- [ ] Quality gate clean
