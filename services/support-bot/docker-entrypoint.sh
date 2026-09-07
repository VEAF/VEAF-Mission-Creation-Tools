#!/bin/sh
# The one thing the container has to do before the service starts: make sure the clone it owns
# exists.
#
# The service *refreshes* a clone (`git fetch --prune`, then `git reset --hard`) but never creates
# one — `open_checkout` raises `CheckoutUnavailable` on a directory with no `.git`, and both `/bug`
# and `/suggest` are then not published at all. On a host that is a working copy, somebody cloned it
# by hand. In a container, nobody did: the checkout volume starts empty.
#
# Four decisions, each of them the answer to a way this went wrong in review:
#
#   * a failed clone does NOT stop the service. A momentarily unreachable GitHub would otherwise
#     take `/ask` down with it — a documentation assistant that needs nothing from the repository.
#     Which is also why the clone runs under a **timeout**: a connection that stalls instead of
#     failing would hold this shell for ever, and the service would never start at all;
#   * the guard asks git for a **usable** HEAD, not for the presence of `.git`. Measured in review:
#     `git clone` creates `.git` first, so a clone killed part-way leaves a directory that every
#     later start accepts and never repairs — `fetch` and `reset --hard` both succeed against it,
#     the service reports itself fresh, and every location it publishes carries an unknown revision,
#     for ever, with nothing in the log. That state is not exotic: this shell has no SIGTERM handler
#     while it clones, so `docker stop` during the first start reaches SIGKILL ten seconds later,
#     mid-clone;
#   * **what gets deleted is a half-written clone and nothing else.** The checkout path comes from
#     the environment, so an operator who points it at `/app/state` — the other writable volume, the
#     one holding the quota counters, the filed-issue ledger and the thread links — would otherwise
#     have that erased on the next start, silently, by the cleanup below. A directory is only wiped
#     when it *contains* a `.git`; anything else non-empty is left untouched and reported;
#   * the last line is `exec`. Without it this shell stays PID 1, swallows the SIGTERM that
#     `docker stop` sends, and the clean shutdown never runs — the container is then killed at ten
#     seconds with an exchange in flight.
set -u

#: Longest the first clone may take. 87 MiB shallow, measured; five minutes is a slow link, not a
#: stalled one, and past it starting `/ask` matters more than having a checkout.
CLONE_TIMEOUT=300s

checkout="${SUPPORT_BOT_CHECKOUT_PATH:-}"
if [ -n "${checkout}" ] && ! git -C "${checkout}" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
    url="${VEAF_CLONE_URL:-https://github.com/VEAF/VEAF-Mission-Creation-Tools.git}"
    branch="${SUPPORT_BOT_CHECKOUT_BRANCH:-develop}"
    # The remote is named the way the service will refresh it. It accepts an override and fetches
    # from whatever name it was given, so a clone that always says `origin` would make every refresh
    # fail on a deployment that set one.
    remote="${SUPPORT_BOT_CHECKOUT_REMOTE:-origin}"

    clone=yes
    if [ -e "${checkout}/.git" ]; then
        # A repository with no usable HEAD: the clone died part-way. Its remains have to go, since
        # git refuses a non-empty destination.
        echo "entrypoint: clearing an unusable checkout at ${checkout}"
        find "${checkout}" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    elif [ -n "$(ls -A "${checkout}" 2>/dev/null)" ]; then
        # Not a repository, and not empty. This is somebody else's data — possibly the state volume,
        # mounted here by mistake. Deleting it is the one thing that must not happen.
        echo "entrypoint: WARNING ${checkout} is not empty and not a git repository; leaving it" >&2
        echo "entrypoint: WARNING /bug and /suggest will not be published" >&2
        clone=no
    fi

    if [ "${clone}" = yes ]; then
        # The destination and the branch, never the URL. `checkout.py` refuses to publish what git
        # writes for a stated reason — it carries the remote's URL, a server-side path, sometimes a
        # user name — and an override cloning a private repository looks like
        # `https://x-access-token:<token>@github.com/...`, which would land in the container log.
        echo "entrypoint: cloning branch ${branch} into ${checkout}"
        # Shallow and single-branch: the service reads doc/, the sources, .backlog/, ROADMAP.md and
        # CHANGELOG.md. It never reads history, and the refresh keeps a shallow clone shallow.
        if timeout --kill-after=10s "${CLONE_TIMEOUT}" \
            git clone --quiet --depth 1 --single-branch \
                --origin "${remote}" --branch "${branch}" "${url}" "${checkout}"; then
            echo "entrypoint: clone ready"
        else
            echo "entrypoint: WARNING the clone failed or timed out after ${CLONE_TIMEOUT}" >&2
            echo "entrypoint: WARNING /bug and /suggest will not be published" >&2
        fi
    fi
fi

exec python -m veaf_support_bot "$@"
