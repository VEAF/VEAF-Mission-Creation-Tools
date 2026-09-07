# 02 — One command brings it up, and brings it back

Status: ⬜ ready

Type: feat

## What to build

A `compose.yml` beside the service, building from this directory, so the host's whole procedure is
`git pull` then `docker compose up -d --build`.

What it has to declare, and why each line is there:

| Declaration | Why |
|---|---|
| `build: .` | Decided: built on place from git, no registry and no publishing credential |
| `restart: unless-stopped` | The service dies silently otherwise — the process is up, the container says *running*, and nobody gets an answer |
| a volume on `/app/state` | Four files must survive a restart; without it `docker rm` hands everyone a fresh quota and orphans every followed thread |
| a volume on the checkout | So the clone is made once, not on every start |
| `env_file: .env` | The service reads the environment and never a file, which is why the container is the natural home for it |
| the health port | Only if something local watches it; nothing has to reach the service from outside |

`.env` stays out of the image — `tests/test_packaging.py` already asserts it never reaches a layer.

## What this deliberately does not do

No reverse proxy, no exposed port on the internet: nothing calls this service from outside. It calls
Discord, GitHub and the Worker, and answers `/readyz` to whatever runs beside it.

## Definition of done

- [ ] `compose.yml` builds and starts the service with state and checkout on named volumes
- [ ] `docker compose up -d` on a clean host produces a bot that answers, given a filled `.env`
- [ ] A killed container comes back on its own
- [ ] The state files are still there after `docker compose down && up -d`
- [ ] Quality gate clean
