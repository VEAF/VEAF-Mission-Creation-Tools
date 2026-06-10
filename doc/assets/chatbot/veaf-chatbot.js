/*
 * VEAF documentation chatbot widget (POC).
 *
 * Self-injects a floating button + compact chat panel into the MkDocs Material page,
 * detects the page language (FR/EN), and streams answers from the Cloudflare Worker proxy
 * over Server-Sent Events. Markdown is rendered with marked + DOMPurify (loaded from CDN).
 *
 * Configure the Worker endpoint by setting `window.VEAF_CHATBOT_ENDPOINT` before this script
 * loads, otherwise edit the ENDPOINT fallback below to your deployed *.workers.dev URL.
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

  let marked = null;
  let DOMPurify = null;
  const renderers = import(
    "https://cdn.jsdelivr.net/npm/marked@15/lib/marked.esm.js"
  )
    .then((m) => {
      marked = m.marked || m.default;
      return import("https://cdn.jsdelivr.net/npm/dompurify@3/dist/purify.es.mjs");
    })
    .then((d) => {
      DOMPurify = d.default || d;
    })
    .catch(() => {
      /* Fall back to plain text rendering if the CDN is unavailable. */
    });

  function renderMarkdown(text) {
    if (marked && DOMPurify) {
      return DOMPurify.sanitize(marked.parse(text));
    }
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  // --- DOM construction ----------------------------------------------------
  const fab = document.createElement("button");
  fab.className = "veaf-chat-fab";
  fab.type = "button";
  fab.title = t.open;
  fab.setAttribute("aria-label", t.open);
  fab.textContent = "💬";

  const panel = document.createElement("div");
  panel.className = "veaf-chat-panel";
  panel.innerHTML = `
    <div class="veaf-chat-resize-handle" title="${t.resize}"></div>
    <div class="veaf-chat-header">
      <span>${t.title}</span>
      <span>
        <button type="button" data-action="clear" title="${t.clear}">⟳</button>
        <button type="button" data-action="close" title="${t.close}">✕</button>
      </span>
    </div>
    <div class="veaf-chat-messages"></div>
    <div class="veaf-chat-input">
      <textarea rows="2" placeholder="${t.placeholder}"></textarea>
      <button type="button" data-action="send">${t.send}</button>
    </div>`;

  document.body.appendChild(fab);
  document.body.appendChild(panel);

  const messagesEl = panel.querySelector(".veaf-chat-messages");
  const textarea = panel.querySelector("textarea");
  const sendBtn = panel.querySelector('[data-action="send"]');
  const resizeHandle = panel.querySelector(".veaf-chat-resize-handle");

  // Resizable sidebar (ported from Solde): drag the left edge, width persisted in localStorage.
  const MIN_WIDTH = 280;
  const MAX_WIDTH = 800;
  const clampWidth = (w) => Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, w));
  let panelWidth = clampWidth(parseInt(localStorage.getItem("veafChatWidth"), 10) || 380);
  panel.style.width = `${panelWidth}px`;

  resizeHandle.addEventListener("mousedown", (e) => {
    e.preventDefault();
    const startX = e.clientX;
    const startWidth = panelWidth;
    const onMove = (ev) => {
      panelWidth = clampWidth(startWidth + (startX - ev.clientX));
      panel.style.width = `${panelWidth}px`;
    };
    const onUp = () => {
      localStorage.setItem("veafChatWidth", String(panelWidth));
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
  });

  /** Conversation history sent to the Worker. */
  const history = [];
  let streaming = false;

  function addBubble(role, html) {
    const el = document.createElement("div");
    el.className = `veaf-chat-msg ${role}`;
    el.innerHTML = html;
    messagesEl.appendChild(el);
    messagesEl.scrollTop = messagesEl.scrollHeight;
    return el;
  }

  function welcomeOnce() {
    if (!messagesEl.childElementCount) addBubble("assistant", renderMarkdown(t.welcome));
  }

  function togglePanel(open) {
    const show = open ?? !panel.classList.contains("is-open");
    panel.classList.toggle("is-open", show);
    fab.style.display = show ? "none" : "";
    if (show) {
      welcomeOnce();
      textarea.focus();
    }
  }

  fab.addEventListener("click", () => togglePanel());
  panel.querySelector('[data-action="close"]').addEventListener("click", () => togglePanel(false));
  panel.querySelector('[data-action="clear"]').addEventListener("click", () => {
    history.length = 0;
    messagesEl.innerHTML = "";
    welcomeOnce();
  });

  async function send() {
    const text = textarea.value.trim();
    if (!text || streaming) return;
    textarea.value = "";
    addBubble("user", renderMarkdown(text));
    history.push({ role: "user", content: text });

    streaming = true;
    sendBtn.disabled = true;
    const bubble = addBubble("assistant", "…");
    let answer = "";

    try {
      await renderers;
      const res = await fetch(ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: history, lang }),
      });
      if (!res.ok || !res.body) throw new Error("HTTP " + res.status);

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
            answer = parsed.error;
            bubble.innerHTML = renderMarkdown(answer);
            throw new Error("stream error");
          }
          if (parsed.text) {
            answer += parsed.text;
            bubble.innerHTML = renderMarkdown(answer);
            messagesEl.scrollTop = messagesEl.scrollHeight;
          }
        }
      }
      if (answer) history.push({ role: "assistant", content: answer });
    } catch (e) {
      if (!answer) bubble.innerHTML = renderMarkdown(t.error);
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
})();
