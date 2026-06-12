"""Documentation chatbot worker (CHATBOT-CLI-003).

Answers a question about the VEAF documentation with RAG, using the *user's own*
Gemini API key: embed the question (``gemini-embedding-001``, 768d), rank the
cached index by cosine similarity, then stream a grounded answer from
``gemini-2.5-flash-lite``. Mirrors the Cloudflare Worker's behaviour so the CLI
and the website chatbot answer alike.
"""

from __future__ import annotations

import json
import math
import os
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import requests
from veaf_libs import user_config
from veaf_libs.base_worker import BaseWorker
from veaf_libs.i18n import t
from veaf_libs.logger import logger

from .index_store import DEFAULT_CACHE_DIR, DEFAULT_INDEX_BASE_URL, EMBED_DIMS, DocIndex, fetch_index

MODEL = "gemini-2.5-flash-lite"
EMBED_MODEL = "gemini-embedding-001"
GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
TOP_K = 6
MAX_HISTORY = 12
_TIMEOUT = 60

#: Config key (in ``~/veafmct.yaml``) and environment variable for the Gemini key.
API_KEY_ENV = "GEMINI_API_KEY"
API_KEY_CONFIG = "gemini_api_key"


class MissingApiKeyError(RuntimeError):
    """Raised when no Gemini API key can be resolved."""


def resolve_api_key(explicit: str | None = None) -> str:
    """Resolve the Gemini API key: explicit > ``GEMINI_API_KEY`` env > user config.

    Args:
        explicit: A key passed directly (wins over every other source).

    Returns:
        The resolved API key.

    Raises:
        MissingApiKeyError: No key was found in any source.
    """
    key = explicit or os.environ.get(API_KEY_ENV) or user_config.get(API_KEY_CONFIG)
    if not key:
        raise MissingApiKeyError(t("ask.no_api_key", env=API_KEY_ENV, config=API_KEY_CONFIG))
    return str(key)


def _system_instruction(lang: str, passages: str) -> str:
    """Build the system prompt framing the model as the VEAF docs assistant (mirrors the Worker)."""
    lang_name = "English" if lang == "en" else "French"
    guide = (
        "You are the VEAF Mission Creation Tools documentation assistant. "
        "Answer ONLY using the documentation excerpts provided below. "
        f"Always reply in {lang_name} to match the user. "
        "If the answer is not in the excerpts, say so plainly and point to the most relevant section. "
        "Be concise, use Markdown, and reference doc page titles when helpful."
    )
    return f"{guide}\n\n---\n\n{passages}"


class DocChatWorker(BaseWorker):
    """Answer documentation questions with RAG, using the user's Gemini key."""

    def __init__(
        self,
        lang: str = "fr",
        api_key: str | None = None,
        base_url: str = DEFAULT_INDEX_BASE_URL,
        cache_dir: Path = DEFAULT_CACHE_DIR,
    ) -> None:
        """Initialize the worker.

        Args:
            lang: Documentation language (``"fr"`` / ``"en"``).
            api_key: Explicit Gemini key; falls back to env then user config.
            base_url: Base URL the index assets are published under.
            cache_dir: Local index cache directory.

        Raises:
            MissingApiKeyError: No Gemini API key could be resolved.
        """
        self.lang = "en" if lang == "en" else "fr"
        self.api_key = resolve_api_key(api_key)
        self.base_url = base_url
        self.cache_dir = cache_dir
        self._index: DocIndex | None = None

    @property
    def index(self) -> DocIndex:
        """The documentation index, downloaded and cached on first access."""
        if self._index is None:
            self._index = fetch_index(self.lang, base_url=self.base_url, cache_dir=self.cache_dir)
        return self._index

    def _embed(self, text: str) -> list[float]:
        """Embed a single text with the Gemini embeddings API (RETRIEVAL_QUERY)."""
        url = f"{GEMINI_BASE}/{EMBED_MODEL}:embedContent?key={self.api_key}"
        body: Any = {
            "model": f"models/{EMBED_MODEL}",
            "content": {"parts": [{"text": text}]},
            "taskType": "RETRIEVAL_QUERY",
            "outputDimensionality": EMBED_DIMS,
        }
        try:
            resp = requests.post(url, json=body, timeout=_TIMEOUT)
        except requests.RequestException as exc:
            raise RuntimeError(t("ask.gemini_error", status="network")) from exc
        if resp.status_code != 200:
            raise RuntimeError(t("ask.gemini_error", status=resp.status_code))
        return resp.json()["embedding"]["values"]

    def _retrieve(self, query: str, top_k: int = TOP_K) -> str:
        """Embed the query, rank the index by cosine similarity, return the top passages."""
        raw = self._embed(query)
        norm = math.sqrt(sum(x * x for x in raw)) or 1.0
        q = [x / norm for x in raw]

        vectors = self.index.vectors
        scored: list[tuple[float, int]] = []
        for i in range(self.index.count):
            off = i * EMBED_DIMS
            dot = 0.0
            for d in range(EMBED_DIMS):
                dot += q[d] * vectors[off + d]
            scored.append((dot, i))
        scored.sort(key=lambda s: s[0], reverse=True)

        passages = []
        for _score, i in scored[:top_k]:
            chunk = self.index.texts[i]
            title = chunk.get("title") or chunk.get("path") or ""
            passages.append(f"# {title}\n\n{chunk.get('text', '')}")
        return "\n\n---\n\n".join(passages)

    def _contents(self, question: str, history: list[dict[str, str]] | None) -> list[dict]:
        """Build the Gemini ``contents`` from the trimmed history plus the new question."""
        contents: list[dict] = []
        for msg in (history or [])[-MAX_HISTORY:]:
            text = (msg.get("content") or "").strip()
            if not text:
                continue
            role = "model" if msg.get("role") == "assistant" else "user"
            contents.append({"role": role, "parts": [{"text": text}]})
        contents.append({"role": "user", "parts": [{"text": question}]})
        return contents

    def ask(self, question: str, history: list[dict[str, str]] | None = None) -> Iterator[str]:
        """Answer a question, streaming the grounded reply as text chunks.

        Args:
            question: The user's question.
            history: Prior turns as ``{"role", "content"}`` dicts (optional).

        Yields:
            Answer text fragments as they arrive from the model.

        Raises:
            RuntimeError: The Gemini API returned an error.
        """
        passages = self._retrieve(question)
        body: Any = {
            "systemInstruction": {"parts": [{"text": _system_instruction(self.lang, passages)}]},
            "contents": self._contents(question, history),
        }
        url = f"{GEMINI_BASE}/{MODEL}:streamGenerateContent?alt=sse&key={self.api_key}"
        try:
            response = requests.post(url, json=body, timeout=_TIMEOUT, stream=True)
        except requests.RequestException as exc:
            raise RuntimeError(t("ask.gemini_error", status="network")) from exc
        with response as resp:
            if resp.status_code != 200:
                raise RuntimeError(t("ask.gemini_error", status=resp.status_code))
            for raw in resp.iter_lines(decode_unicode=True):
                line = raw.decode("utf-8") if isinstance(raw, bytes) else raw
                if not line or not line.startswith("data:"):
                    continue
                payload = line[len("data:") :].strip()
                if not payload or payload == "[DONE]":
                    continue
                yield from _extract_text(payload)

    def work(self) -> object:
        """Not used: the chatbot is driven interactively via :meth:`ask`."""
        raise NotImplementedError("DocChatWorker is driven via ask()")


def _extract_text(payload: str) -> Iterator[str]:
    """Yield the text parts from one Gemini SSE ``data:`` JSON payload (best-effort)."""
    try:
        data = json.loads(payload)
    except ValueError:
        logger.debug(f"Skipping non-JSON SSE payload: {payload[:80]}")
        return
    for cand in data.get("candidates", []):
        for part in cand.get("content", {}).get("parts", []):
            text = part.get("text")
            if text:
                yield text
