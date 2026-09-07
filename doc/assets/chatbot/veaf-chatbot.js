/*
 * VEAF documentation chatbot widget (POC).
 *
 * Self-injects a floating button + compact resizable sidebar into the MkDocs Material page,
 * detects the page language (FR/EN), and streams answers from the Cloudflare Worker proxy
 * over Server-Sent Events.
 *
 * XSS posture: no `innerHTML` is ever assigned. Markdown is rendered to a *sanitized DOM
 * fragment* via DOMPurify (RETURN_DOM_FRAGMENT) and inserted with `replaceChildren`; the static
 * UI is built with `createElement`. marked + DOMPurify are lazily imported the first time the
 * panel is opened (zero cost for users who never open the assistant).
 *
 * Configure the Worker endpoint via `window.VEAF_CHATBOT_ENDPOINT` before this script loads,
 * otherwise edit the ENDPOINT fallback below.
 */
(function () {
  "use strict";

  const ENDPOINT =
    window.VEAF_CHATBOT_ENDPOINT ||
    "https://veaf-docs-chatbot.YOUR-SUBDOMAIN.workers.dev/chat";

  const I18N = {
    fr: {
      title: "Assistant VEAF",
      placeholder: "Posez votre question…",
      send: "Envoyer",
      open: "Ouvrir l'assistant",
      close: "Fermer",
      clear: "Effacer",
      resize: "Redimensionner",
      error: "Une erreur est survenue.",
      welcome: "Bonjour ! Posez-moi une question sur les outils VEAF.",
      // Said up front, and not only when it happens: someone who meets the wall without warning
      // concludes the assistant is broken, and does not come back.
      welcomeNote:
        "Je tourne sur une allocation gratuite partagée par tous les visiteurs du site : " +
        "un jour chargé, elle peut s'épuiser. Elle repart le matin suivant.",
    },
    en: {
      title: "VEAF Assistant",
      placeholder: "Ask your question…",
      send: "Send",
      open: "Open the assistant",
      close: "Close",
      clear: "Clear",
      resize: "Resize",
      error: "Something went wrong.",
      welcome: "Hi! Ask me anything about the VEAF tools.",
      welcomeNote:
        "I run on a free allowance shared by every visitor of the site: on a busy day it can " +
        "run out. It refills the next morning.",
    },
  };

  /** Detect the page language from <html lang> or an /en/ URL segment; default to FR. */
  function detectLang() {
    const htmlLang = (document.documentElement.lang || "").toLowerCase();
    if (htmlLang.startsWith("en")) return "en";
    if (htmlLang.startsWith("fr")) return "fr";
    return location.pathname.includes("/en/") ? "en" : "fr";
  }

  const lang = detectLang();
  const t = I18N[lang];

  // Lazily load marked + DOMPurify (only when the panel is first opened).
  let marked = null;
  let DOMPurify = null;
  let renderersPromise = null;
  function ensureRenderers() {
    if (!renderersPromise) {
      renderersPromise = import("https://cdn.jsdelivr.net/npm/marked@15/lib/marked.esm.js")
        .then((m) => {
          marked = m.marked || m.default;
          return import("https://cdn.jsdelivr.net/npm/dompurify@3/dist/purify.es.mjs");
        })
        .then((d) => {
          DOMPurify = d.default || d;
        })
        .catch(() => {
          /* Fall back to plain-text rendering if the CDN is unavailable. */
        });
    }
    return renderersPromise;
  }

  /** Render markdown to a SANITIZED DOM fragment (never a string → no innerHTML). */
  function markdownToNode(text) {
    if (marked && DOMPurify) {
      return DOMPurify.sanitize(marked.parse(text), { RETURN_DOM_FRAGMENT: true });
    }
    return document.createTextNode(text); // safe fallback before the CDN loads
  }

  /** Tiny createElement helper. `attrs.class`/`attrs.text` are special-cased; rest become attributes. */
  function el(tag, attrs, ...children) {
    const node = document.createElement(tag);
    for (const key in attrs || {}) {
      if (key === "class") node.className = attrs[key];
      else if (key === "text") node.textContent = attrs[key];
      else node.setAttribute(key, attrs[key]);
    }
    for (const child of children) node.append(child);
    return node;
  }

  // --- DOM construction (no innerHTML) -------------------------------------
  const fab = el("button", { class: "veaf-chat-fab", type: "button", title: t.open, "aria-label": t.open });
  fab.textContent = "💬";

  const messagesEl = el("div", { class: "veaf-chat-messages" });
  const textarea = el("textarea", { rows: "2", placeholder: t.placeholder });
  const sendBtn = el("button", { type: "button", text: t.send });
  const clearBtn = el("button", { type: "button", title: t.clear, text: "⟳" });
  const closeBtn = el("button", { type: "button", title: t.close, text: "✕" });
  const resizeHandle = el("div", { class: "veaf-chat-resize-handle", title: t.resize });

  const panel = el(
    "div",
    { class: "veaf-chat-panel" },
    resizeHandle,
    el("div", { class: "veaf-chat-header" }, el("span", { text: t.title }), el("span", {}, clearBtn, closeBtn)),
    messagesEl,
    el("div", { class: "veaf-chat-input" }, textarea, sendBtn),
  );

  document.body.appendChild(fab);
  document.body.appendChild(panel);

  /** Resizable sidebar (ported from Solde): drag the left edge, width persisted in localStorage. */
  function initResize(targetPanel, handle) {
    const MIN_WIDTH = 280;
    const MAX_WIDTH = 800;
    const clampWidth = (w) => Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, w));
    let panelWidth = clampWidth(parseInt(localStorage.getItem("veafChatWidth"), 10) || 380);
    targetPanel.style.width = `${panelWidth}px`;

    handle.addEventListener("mousedown", (e) => {
      e.preventDefault();
      const startX = e.clientX;
      const startWidth = panelWidth;
      const onMove = (ev) => {
        panelWidth = clampWidth(startWidth + (startX - ev.clientX));
        targetPanel.style.width = `${panelWidth}px`;
      };
      const onUp = () => {
        localStorage.setItem("veafChatWidth", String(panelWidth));
        window.removeEventListener("mousemove", onMove);
        window.removeEventListener("mouseup", onUp);
      };
      window.addEventListener("mousemove", onMove);
      window.addEventListener("mouseup", onUp);
    });
  }

  /** Conversation history sent to the Worker. */
  const history = [];
  let streaming = false;

  function addBubble(role, node) {
    const bubble = el("div", { class: `veaf-chat-msg ${role}` });
    bubble.replaceChildren(node);
    messagesEl.appendChild(bubble);
    messagesEl.scrollTop = messagesEl.scrollHeight;
    return bubble;
  }

  /**
   * Greet, and say once that the assistant is rationed.
   *
   * Built as real elements rather than through `markdownToNode`: the panel calls this without
   * awaiting `ensureRenderers`, so on the very first open marked is still loading and markdown
   * would render as its own source — literal asterisks and a run-on line.
   */
  function welcomeOnce() {
    if (messagesEl.childElementCount) return;
    const content = document.createDocumentFragment();
    content.appendChild(el("p", { text: t.welcome }));
    content.appendChild(el("p", { class: "veaf-chat-note", text: t.welcomeNote }));
    addBubble("assistant", content);
  }

  function togglePanel(open) {
    const show = open ?? !panel.classList.contains("is-open");
    panel.classList.toggle("is-open", show);
    fab.style.display = show ? "none" : "";
    if (show) {
      ensureRenderers();
      welcomeOnce();
      textarea.focus();
    }
  }

  fab.addEventListener("click", () => togglePanel());
  closeBtn.addEventListener("click", () => togglePanel(false));
  clearBtn.addEventListener("click", () => {
    history.length = 0;
    messagesEl.replaceChildren();
    welcomeOnce();
  });

  /**
   * Pull the Worker's own error text out of an SSE body.
   *
   * The Worker answers a refusal with a real status (429 for a spent quota) *and* an SSE payload
   * carrying the localized explanation. Reading only the status threw that explanation away, so a
   * rationed assistant showed the same "something went wrong" as a crashed one.
   */
  function errorFromSse(text) {
    for (const line of String(text || "").split("\n")) {
      const trimmed = line.trim();
      if (!trimmed.startsWith("data:")) continue;
      try {
        const parsed = JSON.parse(trimmed.slice(5).trim());
        if (parsed && parsed.error) return String(parsed.error);
      } catch {
        // Not a JSON event; keep looking.
      }
    }
    return null;
  }

  /** POST the conversation and consume the SSE stream, invoking onChunk/onError per event. */
  async function streamAnswer({ endpoint, messages, lang: language, onChunk, onError }) {
    const res = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ messages, lang: language }),
    });
    if (!res.ok || !res.body) {
      const explained = res.body ? errorFromSse(await res.text().catch(() => "")) : null;
      if (explained) {
        onError(explained);
        return;
      }
      throw new Error("HTTP " + res.status);
    }

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";
      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed.startsWith("data:")) continue;
        const raw = trimmed.slice(5).trim();
        if (!raw || raw === "[DONE]") continue;
        let parsed;
        try {
          parsed = JSON.parse(raw);
        } catch {
          continue;
        }
        if (parsed.error) {
          onError(parsed.error);
          return;
        }
        if (parsed.text) onChunk(parsed.text);
      }
    }
  }

  async function send() {
    const text = textarea.value.trim();
    if (!text || streaming) return;
    textarea.value = "";
    addBubble("user", markdownToNode(text));
    history.push({ role: "user", content: text });

    streaming = true;
    sendBtn.disabled = true;
    await ensureRenderers();
    const bubble = addBubble("assistant", markdownToNode("…"));
    let answer = "";

    try {
      await streamAnswer({
        endpoint: ENDPOINT,
        messages: history,
        lang,
        onChunk: (chunk) => {
          answer += chunk;
          bubble.replaceChildren(markdownToNode(answer));
          messagesEl.scrollTop = messagesEl.scrollHeight;
        },
        onError: (msg) => {
          answer = msg;
          bubble.replaceChildren(markdownToNode(answer));
        },
      });
      if (answer) history.push({ role: "assistant", content: answer });
    } catch {
      if (!answer) bubble.replaceChildren(markdownToNode(t.error));
    } finally {
      streaming = false;
      sendBtn.disabled = false;
    }
  }

  sendBtn.addEventListener("click", send);
  textarea.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      send();
    }
  });

  initResize(panel, resizeHandle);
})();
