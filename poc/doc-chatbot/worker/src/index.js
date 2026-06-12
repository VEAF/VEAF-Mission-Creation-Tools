/**
 * VEAF documentation chatbot — Cloudflare Worker proxy (POC, RAG edition).
 *
 * Responsibilities:
 *   - CORS / domain allow-list (anti-CSRF): only accept requests from known doc origins.
 *   - Per-IP rate-limiting via KV (burst + daily guards).
 *   - RAG retrieval: embed the user question (Gemini embeddings), then rank the documentation
 *     passages by cosine similarity against an embeddings index stored in KV (binary Float32
 *     vectors, L2-normalized so cosine == dot product), and inject only the top-K passages into
 *     the prompt — keeping each request small enough to stay well under the Gemini free-tier
 *     tokens-per-minute ceiling. The similarity search runs in the Worker (no paid vector DB).
 *   - Proxy the conversation to Gemini and stream the answer back to the browser as SSE.
 *
 * The Gemini API key is held as a Worker Secret (GEMINI_API_KEY) and never reaches the client.
 *
 * Bindings expected (see wrangler.toml):
 *   - env.GEMINI_API_KEY  (Secret)         Google Gemini API key (used for embeddings + generation).
 *   - env.CHAT_KV         (KV namespace)   per-IP rate-limit counters + the embeddings index
 *                                          (`idx:vec:{lang}` binary blob, `idx:txt:{lang}:{i}` JSON).
 */

const MODEL = "gemini-2.5-flash-lite";
const EMBED_MODEL = "gemini-embedding-001";
const EMBED_DIMS = 768; // embedding dimensionality (must match the index built by build-index.mjs)
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

/**
 * Map an upstream Gemini failure status to the right localized user message.
 * A 429 (the free-tier quota was hit) becomes the "too many requests" message
 * rather than the generic "unavailable", so the pilot knows to simply retry.
 */
function upstreamErrorMessage(lang, status) {
  return status === 429 ? MESSAGES[lang].rateLimited : MESSAGES[lang].unavailable;
}

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
  try {
    const [minRaw, dayRaw] = await Promise.all([env.CHAT_KV.get(minKey), env.CHAT_KV.get(dayKey)]);
    const minCount = minRaw ? parseInt(minRaw, 10) : 0;
    const dayCount = dayRaw ? parseInt(dayRaw, 10) : 0;
    if (minCount >= RL_MAX_PER_WINDOW || dayCount >= RL_MAX_PER_DAY) return false;
    await Promise.all([
      env.CHAT_KV.put(minKey, String(minCount + 1), { expirationTtl: RL_WINDOW }),
      env.CHAT_KV.put(dayKey, String(dayCount + 1), { expirationTtl: 86400 }),
    ]);
    return true;
  } catch {
    // Fail open: if KV is unavailable, skip rate-limiting rather than 500 the whole request.
    return true;
  }
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
  if (!res.ok) {
    const err = new Error(`embed ${res.status}`);
    err.status = res.status;
    throw err;
  }
  const json = await res.json();
  return json.embedding.values;
}

/** In-place L2 normalization (so cosine similarity reduces to a dot product). */
function l2normalize(v) {
  let sumSq = 0;
  for (let i = 0; i < v.length; i++) sumSq += v[i] * v[i];
  const norm = Math.sqrt(sumSq) || 1;
  for (let i = 0; i < v.length; i++) v[i] /= norm;
  return v;
}

// Per-isolate cache of the language-scoped vector blobs (loaded once, reused across requests).
const vecCache = {};

/** Load the binary Float32 vector blob for a language from KV (cached on the isolate). */
async function loadVectors(env, lang) {
  if (!vecCache[lang]) {
    const buf = await env.CHAT_KV.get(`idx:vec:${lang}`, { type: "arrayBuffer" });
    if (!buf) throw new Error(`no index for ${lang}`);
    vecCache[lang] = new Float32Array(buf);
  }
  return vecCache[lang];
}

/**
 * Retrieve the most relevant documentation passages: embed the query, rank every indexed vector by
 * cosine similarity (dot product on normalized vectors) in the Worker, then fetch the top-K texts
 * from KV. Returns the concatenated passages to inject into the prompt.
 */
async function retrieveContext(env, lang, query) {
  const q = l2normalize(Float32Array.from(await embed(env, query, "RETRIEVAL_QUERY")));
  const vecs = await loadVectors(env, lang);
  const count = Math.floor(vecs.length / EMBED_DIMS);

  // Keep the running top-K (small, so an array + sort is cheaper than a heap here).
  const top = [];
  for (let i = 0; i < count; i++) {
    const off = i * EMBED_DIMS;
    let dot = 0;
    for (let d = 0; d < EMBED_DIMS; d++) dot += q[d] * vecs[off + d];
    if (top.length < TOP_K) {
      top.push({ i, score: dot });
      if (top.length === TOP_K) top.sort((a, b) => a.score - b.score);
    } else if (dot > top[0].score) {
      top[0] = { i, score: dot };
      top.sort((a, b) => a.score - b.score);
    }
  }
  top.sort((a, b) => b.score - a.score);

  const texts = await Promise.all(
    top.map((m) => env.CHAT_KV.get(`idx:txt:${lang}:${m.i}`, { type: "json" })),
  );
  const passages = texts
    .filter(Boolean)
    .map((m) => `# ${m.title || m.path || ""}\n\n${m.text}`);
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
      if (!upstream.ok || !upstream.body) return fail(upstreamErrorMessage(lang, upstream.status));

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

/**
 * Decide whether a request may use the chat endpoint.
 * Browsers must come from an allow-listed Origin (anti-CSRF). Non-browser clients
 * (the `veaf-tools ask` CLI) have no Origin, so they identify with the
 * ``X-VEAF-Client: cli`` header instead; both paths stay capped by the per-IP rate limit.
 */
function isAllowedClient(origin, cliHeader) {
  return cliHeader === "cli" || (!!origin && ALLOWED_ORIGINS.has(origin));
}

// Named exports for unit testing (unused by the Workers runtime, which only calls the default export).
export { latestQuery, toGeminiContents, upstreamErrorMessage, isAllowedClient };

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

    // Allow browsers from a known doc origin (anti-CSRF) or the CLI (X-VEAF-Client header).
    if (!isAllowedClient(origin, request.headers.get("X-VEAF-Client"))) {
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
    } catch (err) {
      return new Response(sse({ error: upstreamErrorMessage(lang, err?.status) }), {
        status: err?.status === 429 ? 429 : 502,
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
