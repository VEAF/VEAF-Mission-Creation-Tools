/**
 * VEAF documentation chatbot — Cloudflare Worker proxy (POC, RAG edition).
 *
 * Responsibilities:
 *   - CORS / domain allow-list (anti-CSRF): only accept requests from known doc origins.
 *   - Per-IP rate-limiting via KV (burst + daily guards).
 *   - RAG retrieval: embed the user question (Gemini embeddings), query the Vectorize index for
 *     the most relevant documentation passages (filtered by language), and inject only those few
 *     passages into the prompt — keeping each request small enough to stay well under the Gemini
 *     free-tier tokens-per-minute ceiling.
 *   - Proxy the conversation to Gemini and stream the answer back to the browser as SSE.
 *
 * The Gemini API key is held as a Worker Secret (GEMINI_API_KEY) and never reaches the client.
 *
 * Bindings expected (see wrangler.toml):
 *   - env.GEMINI_API_KEY  (Secret)         Google Gemini API key (used for embeddings + generation).
 *   - env.CHAT_KV         (KV namespace)   per-IP rate-limit counters.
 *   - env.VEC             (Vectorize)      doc-passage embeddings index (built by scripts/build-index.mjs).
 */

const MODEL = "gemini-2.5-flash-lite";
const EMBED_MODEL = "gemini-embedding-001";
const EMBED_DIMS = 768; // matches the Vectorize index dimensions
const TOP_K = 6; // passages retrieved per question
const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

const MAX_HISTORY = 12; // trim very long conversations sent to the model

// Anti-abuse: per-IP rate limits.
const RL_WINDOW = 60; // seconds
const RL_MAX_PER_WINDOW = 10; // requests / 60s / IP
const RL_MAX_PER_DAY = 100; // requests / 24h / IP

const ALLOWED_ORIGINS = new Set([
  "http://localhost:8000",
  "http://127.0.0.1:8000",
  "https://veaf.github.io",
]);

/** Localized, user-facing messages (kept short, mirroring the Solde tone). */
const MESSAGES = {
  fr: {
    rateLimited: "Trop de requêtes, réessayez dans un instant.",
    unavailable: "Assistant momentanément indisponible.",
    badRequest: "Requête invalide.",
  },
  en: {
    rateLimited: "Too many requests, please try again shortly.",
    unavailable: "Assistant temporarily unavailable.",
    badRequest: "Invalid request.",
  },
};

/** Build the system instruction that frames the model as the VEAF docs assistant. */
function systemInstruction(lang, passages) {
  const langName = lang === "en" ? "English" : "French";
  const guide =
    `You are the VEAF Mission Creation Tools documentation assistant. ` +
    `Answer ONLY using the documentation excerpts provided below. ` +
    `Always reply in ${langName} to match the user. ` +
    `If the answer is not in the excerpts, say so plainly and point to the most relevant section. ` +
    `Be concise, use Markdown, and reference doc page titles when helpful.`;
  return `${guide}\n\n---\n\n${passages}`;
}

function corsHeaders(origin) {
  const headers = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

function sse(data) {
  const payload = typeof data === "string" ? data : JSON.stringify(data);
  return `data: ${payload}\n\n`;
}

/**
 * Per-IP rate-limiting backed by KV. KV is eventually consistent, which is acceptable
 * for an abuse guard on a POC. Returns true when the request is allowed.
 */
async function allowRequest(env, ip) {
  const minKey = `rl:min:${ip}`;
  const dayKey = `rl:day:${ip}`;
  const [minRaw, dayRaw] = await Promise.all([env.CHAT_KV.get(minKey), env.CHAT_KV.get(dayKey)]);
  const minCount = minRaw ? parseInt(minRaw, 10) : 0;
  const dayCount = dayRaw ? parseInt(dayRaw, 10) : 0;
  if (minCount >= RL_MAX_PER_WINDOW || dayCount >= RL_MAX_PER_DAY) return false;
  await Promise.all([
    env.CHAT_KV.put(minKey, String(minCount + 1), { expirationTtl: RL_WINDOW }),
    env.CHAT_KV.put(dayKey, String(dayCount + 1), { expirationTtl: 86400 }),
  ]);
  return true;
}

/** Embed a single text with the Gemini embeddings API. */
async function embed(env, text, taskType) {
  const res = await fetch(`${GEMINI_BASE}/${EMBED_MODEL}:embedContent?key=${env.GEMINI_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: `models/${EMBED_MODEL}`,
      content: { parts: [{ text }] },
      taskType,
      outputDimensionality: EMBED_DIMS,
    }),
  });
  if (!res.ok) throw new Error(`embed ${res.status}`);
  const json = await res.json();
  return json.embedding.values;
}

/**
 * Retrieve the most relevant documentation passages for the query via Vectorize, filtered by
 * language. Returns the concatenated passage texts to inject into the prompt.
 */
async function retrieveContext(env, lang, query) {
  const vector = await embed(env, query, "RETRIEVAL_QUERY");
  const result = await env.VEC.query(vector, {
    topK: TOP_K,
    returnMetadata: "all",
    filter: { lang },
  });
  const passages = (result.matches || [])
    .map((m) => {
      const md = m.metadata || {};
      return md.text ? `# ${md.title || md.path || ""}\n\n${md.text}` : "";
    })
    .filter(Boolean);
  if (!passages.length) throw new Error("no passages retrieved");
  return passages.join("\n\n---\n\n");
}

/** Convert the widget message history into Gemini `contents`. */
function toGeminiContents(messages) {
  return messages
    .filter((m) => m && typeof m.content === "string" && m.content.trim())
    .slice(-MAX_HISTORY)
    .map((m) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{ text: m.content }],
    }));
}

/** Stream a Gemini answer and re-emit it as `data: {"text": ...}` / `data: [DONE]` SSE. */
async function streamGemini(env, lang, messages, passages) {
  const url = `${GEMINI_BASE}/${MODEL}:streamGenerateContent?alt=sse&key=${env.GEMINI_API_KEY}`;
  const body = {
    systemInstruction: { parts: [{ text: systemInstruction(lang, passages) }] },
    contents: toGeminiContents(messages),
    generationConfig: { temperature: 0.3, maxOutputTokens: 1024 },
  };

  const upstream = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  return new ReadableStream({
    async start(controller) {
      const fail = (msg) => {
        controller.enqueue(encoder.encode(sse({ error: msg })));
        controller.close();
      };
      if (!upstream.ok || !upstream.body) return fail(MESSAGES[lang].unavailable);

      const reader = upstream.body.getReader();
      let buffer = "";
      try {
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
            try {
              const parsed = JSON.parse(raw);
              const text = parsed?.candidates?.[0]?.content?.parts?.map((p) => p.text).join("") || "";
              if (text) controller.enqueue(encoder.encode(sse({ text })));
            } catch {
              // Ignore partial/non-JSON keep-alive lines.
            }
          }
        }
        controller.enqueue(encoder.encode(sse("[DONE]")));
        controller.close();
      } catch {
        fail(MESSAGES[lang].unavailable);
      }
    },
  });
}

/** Pick the latest user message to use as the retrieval query. */
function latestQuery(messages) {
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m && m.role === "user" && typeof m.content === "string" && m.content.trim()) {
      return m.content;
    }
  }
  return "";
}

// Named exports for unit testing (unused by the Workers runtime, which only calls the default export).
export { latestQuery, toGeminiContents };

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin");
    const cors = corsHeaders(origin);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }

    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/chat") {
      return new Response("Not found", { status: 404, headers: cors });
    }

    // Domain allow-list (anti-CSRF): reject anything not from a known doc origin.
    if (!origin || !ALLOWED_ORIGINS.has(origin)) {
      return new Response("Forbidden", { status: 403, headers: cors });
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return new Response("Bad request", { status: 400, headers: cors });
    }

    const lang = payload?.lang === "en" ? "en" : "fr";
    const messages = Array.isArray(payload?.messages) ? payload.messages : null;
    const query = messages ? latestQuery(messages) : "";
    if (!messages || !messages.length || !query) {
      return new Response(sse({ error: MESSAGES[lang].badRequest }), {
        status: 400,
        headers: { ...cors, "Content-Type": "text/event-stream" },
      });
    }

    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    if (!(await allowRequest(env, ip))) {
      return new Response(sse({ error: MESSAGES[lang].rateLimited }), {
        status: 429,
        headers: { ...cors, "Content-Type": "text/event-stream" },
      });
    }

    let passages;
    try {
      passages = await retrieveContext(env, lang, query);
    } catch {
      return new Response(sse({ error: MESSAGES[lang].unavailable }), {
        status: 502,
        headers: { ...cors, "Content-Type": "text/event-stream" },
      });
    }

    const stream = await streamGemini(env, lang, messages, passages);
    return new Response(stream, {
      headers: {
        ...cors,
        "Content-Type": "text/event-stream; charset=utf-8",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      },
    });
  },
};
