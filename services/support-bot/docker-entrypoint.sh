#!/bin/sh
# The one thing the container has to do before the service starts: make sure the clone it owns
# exists.
#
# The service *refreshes* a clone (`git fetch --prune`, then `git reset --hard`) but never creates
# one — `open_checkout` raises `CheckoutUnavailable` on a directory with no `.git`, and both `/bug`
# and `/suggest` are then not published at all. On a host that is a working copy, somebody cloned it
# by hand. In a container, nobody did: the checkout volume starts empty.
#
# Two decisions worth stating, because both are easy to get wrong the other way:
#
#   * a failed clone does NOT stop the service. A momentarily unreachable GitHub would otherwise
#     take `/ask` down with it — a documentation assistant that needs nothing from the repository.
#     The service says which commands it publishes, and says why the others are absent;
#   * the guard asks git for a **usable** HEAD, not for the presence of `.git`. Measured in review:
#     `git clone` creates `.git` first, so a clone killed part-way leaves a directory that every
#     later start accepts and never repairs — `fetch` and `reset --hard` both succeed against it,
#     the service reports itself fresh, and every location it publishes carries an unknown
#     revision, for ever, with nothing in the log. That state is not exotic: this shell has no
#     SIGTERM handler while it clones, so `docker stop` during the first start reaches SIGKILL ten
#     seconds later, mid-clone. A `rev-parse --verify HEAD` catches both *no repository* and *half
#     a repository*, and what it catches is wiped and cloned again;
#   * the last line is `exec`. Without it this shell stays PID 1, swallows the SIGTERM that
#     `docker stop` sends, and the clean shutdown never runs — the container is then killed at ten
#     seconds with an exchange in flight.
set -u

checkout="${SUPPORT_BOT_CHECKOUT_PATH:-}"
if [ -n "${checkout}" ] && ! git -C "${checkout}" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
    url="${VEAF_CLONE_URL:-https://github.com/VEAF/VEAF-Mission-Creation-Tools.git}"
    branch="${SUPPORT_BOT_CHECKOUT_BRANCH:-develop}"
    # The destination and the branch, never the URL. `checkout.py` refuses to publish what git
    # writes for a stated reason — it carries the remote's URL, a server-side path, sometimes a
    # user name — and an override cloning a private repository looks like
    # `https://x-access-token:<token>@github.com/...`, which would land in the container log.
    echo "entrypoint: cloning branch ${branch} into ${checkout}"
    # Anything a killed clone left behind goes first: git refuses a non-empty destination, and what
    # is there is half a repository by definition.
    find "${checkout}" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    # Shallow and single-branch: the service reads doc/, the sources, .backlog/, ROADMAP.md and
    # CHANGELOG.md. It never reads history, and the refresh keeps a shallow clone shallow.
    if git clone --quiet --depth 1 --single-branch --branch "${branch}" "${url}" "${checkout}"; then
        echo "entrypoint: clone ready"
    else
        echo "entrypoint: WARNING the clone failed; /bug and /suggest will not be published" >&2
    fi
fi

exec python -m veaf_support_bot "$@"
