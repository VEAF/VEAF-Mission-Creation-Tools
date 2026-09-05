"""Client of the Worker's ``/analyze`` route — the second, optional layer of an explanation.

The tool holds no API key. It posts the bounded excerpt and the catalogue entries it matched
locally to the project's Cloudflare Worker, which owns the Gemini key and frames the model with the
catalogue as its sole authority. ``X-VEAF-Client: logs`` selects the ``logs`` client mode, whose
quota and body ceiling the Worker declares; the header is self-declared and buys nothing an
anonymous caller would not already get.

Do not reintroduce a per-user API key here. That route was tried for the CLI chatbot and abandoned:
PR #453 replaced #452's user-key approach with this keyless one.

**Nothing raised here is fatal.** The catalogue layer alone is a useful answer, and it is the
degraded mode the feature has to work in — no network, corporate proxy, Worker down, quota spent.
:func:`analyse_excerpt` therefore reports its failure as a string the caller can show next to the
catalogue text, rather than as an exception the interface has to turn into a dialog.
"""

from __future__ import annotations

import json

import requests

#: Production Worker endpoint. Same Worker as the documentation chatbot, different route.
DEFAULT_ENDPOINT = "https://veaf-docs-chatbot.veaf.workers.dev/analyze"

#: Selects the Worker's ``logs`` client mode. Not a secret; paired with the Worker's per-IP quota.
LOGS_HEADER = {"X-VEAF-Client": "logs"}

#: Seconds before the request is abandoned. A model answer arrives in a few seconds; a minute means
#: the network is the problem, and the user is looking at a frozen dialog while we wait.
TIMEOUT = 45

#: What the caller is told when the Worker cannot be reached at all.
UNREACHABLE = (
    "Analyse en ligne indisponible (pas de réponse du service). Le catalogue ci-dessus reste valable."
)


class AnalysisUnavailable(RuntimeError):
    """The online layer could not answer. The catalogue layer stands on its own."""


def analyse_excerpt(
    excerpt: str,
    matches: list[dict[str, object]],
    question: str = "",
    lang: str = "fr",
    endpoint: str = DEFAULT_ENDPOINT,
    session: requests.Session | None = None,
) -> str:
    """Ask the Worker to put a bounded excerpt in context, and return what it said.

    Args:
        excerpt: The rendered excerpt from :func:`veaf_logs.excerpt.build_excerpt`, already redacted.
        matches: The catalogue entries matched locally, from
            :func:`veaf_logs.catalogue.to_worker_matches`. They are the model's only authority.
        question: An optional question from the user, prepended to the excerpt.
        lang: ``"fr"`` or ``"en"``; anything else is read as French.
        endpoint: The ``/analyze`` URL, overridable for tests.
        session: A ``requests`` session to post through. Defaults to a one-off request.

    Returns:
        The model's commentary, assembled from the streamed fragments.

    Raises:
        AnalysisUnavailable: The Worker was unreachable, refused the request, or reported an error.
            The message is meant to be shown as it stands.
    """
    body = {
        "lang": "en" if lang == "en" else "fr",
        "excerpt": excerpt,
        "matches": matches,
        "question": question,
    }
    poster = session.post if session is not None else requests.post
    try:
        response = poster(
            endpoint,
            json=body,
            headers={**LOGS_HEADER, "Content-Type": "application/json"},
            timeout=TIMEOUT,
            stream=True,
        )
    except requests.RequestException as exc:
        raise AnalysisUnavailable(UNREACHABLE) from exc

    with response as resp:
        if resp.status_code != 200:
            raise AnalysisUnavailable(f"Analyse en ligne indisponible (code {resp.status_code}).")
        return "".join(_fragments(resp))


def _fragments(response: requests.Response) -> list[str]:
    """Collect the text fragments of one Server-Sent Events answer.

    Args:
        response: The streamed Worker response.

    Returns:
        The fragments, in arrival order.

    Raises:
        AnalysisUnavailable: The stream carried an ``error`` payload — the Worker's way of reporting
            a rate limit or an upstream failure, which arrives with HTTP 200.
    """
    out: list[str] = []
    for raw in response.iter_lines(decode_unicode=True):
        line = raw.decode("utf-8") if isinstance(raw, bytes) else raw
        if not line or not line.startswith("data:"):
            continue
        payload = line[len("data:") :].strip()
        if not payload or payload == "[DONE]":
            continue
        try:
            data = json.loads(payload)
        except ValueError:
            # A fragment that is not JSON is a fragment we cannot read, not a reason to lose the
            # ones that were readable.
            continue
        if isinstance(data, dict) and data.get("error"):
            raise AnalysisUnavailable(str(data["error"]))
        text = data.get("text") if isinstance(data, dict) else None
        if text:
            out.append(str(text))
    return out
