"""Documentation chatbot client — talks to the VEAF Cloudflare Worker (CHATBOT-CLI).

The CLI does not hold any API key: it sends the question to the project's Worker
(``/chat``), which owns the Gemini key server-side, runs the RAG retrieval and
streams a grounded answer back as Server-Sent Events. The CLI identifies itself
with the ``X-VEAF-Client: cli`` header (the Worker's anti-CSRF Origin allow-list
only applies to browsers); the Worker's per-IP rate limit protects the quota.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from typing import Any

import requests
from veaf_libs.base_worker import BaseWorker
from veaf_libs.i18n import t
from veaf_libs.logger import logger

#: Production Worker endpoint (same Worker that powers the documentation website chatbot).
DEFAULT_ENDPOINT = "https://veaf-docs-chatbot.veaf.workers.dev/chat"

#: Identifies a non-browser CLI caller to the Worker (not a secret; paired with the per-IP rate limit).
CLI_HEADER = {"X-VEAF-Client": "cli"}

_TIMEOUT = 60


class WorkerChatWorker(BaseWorker):
    """Answer documentation questions by proxying to the VEAF chatbot Worker."""

    def __init__(self, lang: str = "fr", endpoint: str = DEFAULT_ENDPOINT) -> None:
        """Initialize the client.

        Args:
            lang: Documentation language (``"fr"`` / ``"en"``).
            endpoint: The Worker ``/chat`` URL (overridable for tests).
        """
        self.lang = "en" if lang == "en" else "fr"
        self.endpoint = endpoint

    def ask(self, question: str, history: list[dict[str, str]] | None = None) -> Iterator[str]:
        """Answer a question, streaming the grounded reply as text chunks.

        Args:
            question: The user's question.
            history: Prior turns as ``{"role", "content"}`` dicts (optional).

        Yields:
            Answer text fragments as they arrive from the Worker.

        Raises:
            RuntimeError: The Worker reported an error or was unreachable.
        """
        messages = list(history or []) + [{"role": "user", "content": question}]
        body: Any = {"lang": self.lang, "messages": messages}
        try:
            response = requests.post(
                self.endpoint,
                json=body,
                headers={**CLI_HEADER, "Content-Type": "application/json"},
                timeout=_TIMEOUT,
                stream=True,
            )
        except requests.RequestException as exc:
            raise RuntimeError(t("ask.worker_unreachable")) from exc

        with response as resp:
            if resp.status_code != 200:
                raise RuntimeError(t("ask.worker_error", status=resp.status_code))
            for raw in resp.iter_lines(decode_unicode=True):
                line = raw.decode("utf-8") if isinstance(raw, bytes) else raw
                if not line or not line.startswith("data:"):
                    continue
                payload = line[len("data:") :].strip()
                if not payload or payload == "[DONE]":
                    continue
                yield from _emit(payload)

    def work(self) -> object:
        """Not used: the chatbot is driven interactively via :meth:`ask`."""
        raise NotImplementedError("WorkerChatWorker is driven via ask()")


def _emit(payload: str) -> Iterator[str]:
    """Yield the text of one Worker SSE ``data:`` payload; raise on a server error."""
    try:
        data = json.loads(payload)
    except ValueError:
        logger.debug(f"Skipping non-JSON SSE payload: {payload[:80]}")
        return
    if isinstance(data, dict) and data.get("error"):
        raise RuntimeError(str(data["error"]))
    text = data.get("text") if isinstance(data, dict) else None
    if text:
        yield text
