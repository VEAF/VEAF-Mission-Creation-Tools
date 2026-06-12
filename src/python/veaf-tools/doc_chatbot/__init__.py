"""Documentation chatbot client (CHATBOT-CLI).

Brings the VEAF documentation chatbot to the CLI/TUI. The CLI proxies questions to
the project's Cloudflare Worker (which owns the Gemini key and runs the RAG), so
no per-user API key is required.
"""

from .worker_client import DEFAULT_ENDPOINT, WorkerChatWorker

__all__ = ["WorkerChatWorker", "DEFAULT_ENDPOINT"]
