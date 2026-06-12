"""Documentation chatbot client (CHATBOT-CLI).

Brings the VEAF documentation RAG chatbot to the design-time tooling: download the
embeddings index built by the docs CI, then embed the question and generate a
grounded answer with the user's own Gemini key — no Cloudflare credentials, no
local re-embedding.
"""

from .doc_chat_worker import DocChatWorker, MissingApiKeyError
from .index_store import EMBED_DIMS, DocIndex, fetch_index

__all__ = ["DocChatWorker", "MissingApiKeyError", "DocIndex", "fetch_index", "EMBED_DIMS"]
