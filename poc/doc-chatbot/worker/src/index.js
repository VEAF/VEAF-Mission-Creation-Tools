/**
 * VEAF documentation chatbot — Cloudflare Worker proxy (POC, RAG edition).
 *
 * Responsibilities:
 *   - Admission control: a declared client vocabulary (see CLIENTS) with a quota per client.
 *     Browsers are judged on their Origin (anti-CSRF allow-list); the `X-VEAF-Client` header
 *     only *selects* a non-browser client mode, it never grants access an anonymous caller
 *     would not already have.
 *   - Per-client, per-subject rate-limiting via KV (burst + daily guards), failing to a
 *     stricter per-isolate ceiling — never to "no limit" — when KV is unavailable.
 *   - A request body ceiling enforced before the payload is parsed.
 *   - RAG retrieval (`POST /chat`): embed the user question (Gemini embeddings), then rank the
 *     documentation passages by cosine similarity against an embeddings index stored in KV
 *     (binary Float32 vectors, L2-normalized so cosine == dot product), and inject only the
 *     top-K passages into the prompt — keeping each request small enough to stay well under the
 *     Gemini free-tier tokens-per-minute ceiling. The similarity search runs in the Worker
 *     (no paid vector DB).
 *   - Log analysis (`POST /analyze`): the caller (the `veaf-logs` tool) sends a bounded log
 *     excerpt plus the catalogue entries it already matched locally; the model explains them,
 *     with the catalogue as the sole authority on what a pattern means.
 *   - Proxy the conversation to Gemini and stream the answer back to the caller as SSE.
 *
 * The Gemini API key is held as a Worker Secret (GEMINI_API_KEY) and never reaches the client.
 *
 * Bindings expected (see wrangler.toml):
 *   - env.GEMINI_API_KEY  (Secret)         Google Gemini API key (used for embeddings + generation).
 *   - env.CHAT_KV         (KV namespace)   rate-limit counters + the embeddings index
 *                                          (`idx:vec:{lang}` binary blob, `idx:txt:{lang}:{i}` JSON).
 *   - env.DISCORD_CLIENT_SECRET (Secret)   optional; until it is set, the `discord` client mode
 *                                          is refused outright (it is groundwork, not an open door).
 */

const MODEL = "gemini-2.5-flash-lite";
const EMBED_MODEL = "gemini-embedding-001";
const EMBED_DIMS = 768; // embedding dimensionality (must match the index built by build-index.mjs)
const TOP_K = 6; // passages retrieved per question
const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

const MAX_HISTORY = 12; // trim very long conversations sent to the model

const MAX_EXCERPT_CHARS = 40000; // log excerpt kept out of the prompt beyond this
const MAX_MATCHES = 40; // catalogue entries rendered into the prompt

// Anti-abuse: rate-limit window, and the ceiling used when KV cannot be reached.
const RL_WINDOW = 60; // seconds
const DEGRADED_MAX_PER_WINDOW = 2; // requests / 60s / isolate when KV is down
const DEGRADED_MAX_TRACKED = 5000; // cap on the in-memory degraded counter map

const ALLOWED_ORIGINS = new Set([
  "http://localhost:8000",
  "http://127.0.0.1:8000",
  "https://veaf.github.io",
]);

const ROUTES = new Set(["/chat", "/analyze"]);

/**
 * The declared client vocabulary.
 *
 * A client is a *kind of caller*, never an identity: the `X-VEAF-Client` header only selects
 * one of these entries. It is self-declared, so it must never buy more than a plain anonymous
 * caller gets — in particular it can no longer bypass the browser Origin allow-list, which is
 * what the previous `cliHeader === "cli" || origin allow-listed` admission let any caller do.
 *
 * Each entry carries its own quota and its own body ceiling, so one client hammering the free
 * Gemini quota cannot starve the documentation widget.
 *
 * Fields:
 *   - `routes`           the paths this client may call.
 *   - `headerDeclarable` may this client be selected by the `X-VEAF-Client` header?
 *                        `web` cannot: it is derived from an allow-listed Origin.
 *   - `secretBinding`    name of the env Secret this client must prove it holds, or `null`.
 *                        A client with a secret binding is refused while the Secret is unset.
 *   - `perWindow` / `perDay`  requests allowed per RL_WINDOW / per 24h, per subject.
 *   - `maxBody`          request body ceiling in bytes, enforced before parsing.
 *
 * On the conversational ceiling: the documentation widget replays its *whole* history on every
 * turn and does not trim it client-side, while the Worker caps each answer at 1024 output tokens
 * (~4 KB). MAX_HISTORY turns of that reach a few tens of KB, so 64 KiB is the smallest ceiling
 * that cannot cut a legitimate conversation short. It is still a bound where there was none.
 */
const CLIENTS = {
  web: {
    routes: ["/chat"],
    headerDeclarable: false,
    secretBinding: null,
    perWindow: 10,
    perDay: 100,
    maxBody: 64 * 1024,
  },
  cli: {
    routes: ["/chat"],
    headerDeclarable: true,
    secretBinding: null,
    perWindow: 10,
    perDay: 60,
    maxBody: 64 * 1024,
  },
  logs: {
    routes: ["/analyze"],
    headerDeclarable: true,
    secretBinding: null,
    perWindow: 4,
    perDay: 30,
    maxBody: 128 * 1024,
  },
  discord: {
    routes: ["/chat", "/analyze"],
    headerDeclarable: true,
    secretBinding: "DISCORD_CLIENT_SECRET",
    perWindow: 5,
    perDay: 40,
    maxBody: 64 * 1024,
  },
};

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
    "Access-Control-Allow-Headers": "Content-Type, X-VEAF-Client",
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

// Degraded (KV-less) counters, per isolate. Cleared wholesale if the map ever grows unreasonably:
// this is a last-resort brake, not an accounting ledger.
const degradedCounters = new Map();

/**
 * Last-resort in-isolate burst limiter, used when KV cannot be reached.
 *
 * It counts per (client, subject) inside a fixed RL_WINDOW slot and allows far fewer requests
 * than the KV path. An isolate-local counter is weak — Cloudflare may run several isolates —
 * but it is bounded, which is the whole point: a KV outage must degrade the limit, never remove it.
 *
 * @param {string} key Counter key, typically `${client}:${subject}`.
 * @param {number} now Milliseconds since the epoch (injectable for tests).
 * @returns {boolean} True when the request may proceed.
 */
function degradedAllow(key, now = Date.now()) {
  const slot = Math.floor(now / (RL_WINDOW * 1000));
  if (degradedCounters.size > DEGRADED_MAX_TRACKED) degradedCounters.clear();
  const entry = degradedCounters.get(key);
  if (!entry || entry.slot !== slot) {
    degradedCounters.set(key, { slot, count: 1 });
    return true;
  }
  if (entry.count >= DEGRADED_MAX_PER_WINDOW) return false;
  entry.count += 1;
  return true;
}

/**
 * Read a KV rate-limit counter, treating anything that is not a plain non-negative integer as the
 * worst case (the ceiling itself, so the caller is refused).
 *
 * Absent is zero — that is the normal first request. A *present but unreadable* value is not:
 * `parseInt("NaN")` is `NaN`, `NaN >= limit` is false, so a corrupted counter used to let requests
 * straight through, and writing `String(NaN + 1)` back with a fresh 24 h TTL kept it corrupted for
 * good. A poisoned counter now closes its own gate and, since nothing rewrites it, expires on the
 * TTL it already carries.
 *
 * @param {string|null} raw The stored value.
 * @param {number} limit The ceiling to report when the value cannot be trusted.
 * @returns {number} The counter value, or `limit` when it is unreadable.
 */
function readCounter(raw, limit) {
  if (raw === null || raw === undefined) return 0;
  const text = String(raw).trim();
  if (!text) return 0;
  return /^\d+$/.test(text) ? Number(text) : limit;
}

/**
 * Per-client, per-subject rate-limiting backed by KV. KV is eventually consistent and the
 * read-then-write is not atomic, which is acceptable for an abuse guard on a POC.
 *
 * The subject is the caller's IP for the IP-bound clients; a service that fronts many users
 * behind one IP (the `discord` mode) passes its own per-user subject instead, so its whole
 * community does not share a single daily quota.
 *
 * @param {object} env Worker bindings (needs `CHAT_KV`).
 * @param {string} client A key of CLIENTS.
 * @param {string} subject Rate-limit subject (IP, or a service-supplied user id).
 * @returns {Promise<boolean>} True when the request is allowed.
 */
async function allowRequest(env, client, subject) {
  // Own-property lookup, never a bare read: `CLIENTS["constructor"]` is `Object`, which is truthy
  // and has no `perWindow`, so every comparison below would be `>= undefined` — i.e. false — and
  // the request would be allowed. `resolveClient` already refuses those names, and so does this.
  const spec = Object.prototype.hasOwnProperty.call(CLIENTS, client) ? CLIENTS[client] : null;
  if (!spec) return false;
  const minKey = `rl:min:${client}:${subject}`;
  const dayKey = `rl:day:${client}:${subject}`;
  try {
    const [minRaw, dayRaw] = await Promise.all([env.CHAT_KV.get(minKey), env.CHAT_KV.get(dayKey)]);
    const minCount = readCounter(minRaw, spec.perWindow);
    const dayCount = readCounter(dayRaw, spec.perDay);
    if (minCount >= spec.perWindow || dayCount >= spec.perDay) return false;
    await Promise.all([
      env.CHAT_KV.put(minKey, String(minCount + 1), { expirationTtl: RL_WINDOW }),
      env.CHAT_KV.put(dayKey, String(dayCount + 1), { expirationTtl: 86400 }),
    ]);
    return true;
  } catch {
    // Fail closed-ish: KV is gone, so fall back to a much stricter per-isolate ceiling.
    // Returning true here (as this used to) meant a KV outage silently removed every limit.
    return degradedAllow(`${client}:${subject}`);
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

/**
 * Stream a Gemini answer and re-emit it as `data: {"text": ...}` / `data: [DONE]` SSE.
 *
 * @param {object} env Worker bindings.
 * @param {string} lang `"fr"` or `"en"`, used for the failure messages.
 * @param {Array<object>} contents Gemini-shaped `contents` (already trimmed and mapped).
 * @param {string} instruction The system instruction framing the answer.
 */
async function streamGemini(env, lang, contents, instruction) {
  const url = `${GEMINI_BASE}/${MODEL}:streamGenerateContent?alt=sse&key=${env.GEMINI_API_KEY}`;
  const body = {
    systemInstruction: { parts: [{ text: instruction }] },
    contents,
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

/** Length-independent string comparison, so a wrong secret leaks nothing through timing. */
function secretsMatch(given, expected) {
  if (typeof given !== "string" || typeof expected !== "string") return false;
  if (!expected) return false;
  let diff = given.length ^ expected.length;
  for (let i = 0; i < given.length; i++) {
    diff |= given.charCodeAt(i) ^ expected.charCodeAt(i % expected.length);
  }
  return diff === 0;
}

/**
 * Resolve which declared client, if any, a request belongs to.
 *
 * The rules, in order:
 *   1. A request carrying an `Origin` is a browser request. The allow-list decides, and the
 *      self-declared `X-VEAF-Client` header is ignored — it cannot promote a hostile origin,
 *      and it cannot let an allow-listed page spend another client's quota.
 *   2. Without an `Origin`, the header selects a header-declarable client mode. That grants
 *      no more than the mode's own quota; it is a routing label, not a credential.
 *   3. A mode with a `secretBinding` must additionally present the matching Secret, and is
 *      refused outright while that Secret is unset.
 *
 * @param {string|null} origin The request `Origin` header.
 * @param {string|null} clientHeader The request `X-VEAF-Client` header.
 * @param {{secret?: string|null, env?: object}} [credentials] Presented secret and the bindings
 *   the configured one is read from (`env[spec.secretBinding]`).
 * @returns {{client: string|null, spec: object|null, reason: string|null}} Resolution outcome.
 */
function resolveClient(origin, clientHeader, credentials = {}) {
  if (origin) {
    return ALLOWED_ORIGINS.has(origin)
      ? { client: "web", spec: CLIENTS.web, reason: null }
      : { client: null, spec: null, reason: "origin" };
  }
  const declared = typeof clientHeader === "string" ? clientHeader.trim().toLowerCase() : "";
  const spec = Object.prototype.hasOwnProperty.call(CLIENTS, declared) ? CLIENTS[declared] : null;
  if (!spec || !spec.headerDeclarable) return { client: null, spec: null, reason: "client" };
  if (spec.secretBinding) {
    const expected = credentials.env?.[spec.secretBinding];
    if (!secretsMatch(credentials.secret, expected)) {
      return { client: null, spec: null, reason: "secret" };
    }
  }
  return { client: declared, spec, reason: null };
}

/**
 * Decide whether a request may reach the Worker at all.
 * Thin boolean wrapper over {@link resolveClient}, kept for readability at the call site.
 */
function isAllowedClient(origin, clientHeader, credentials) {
  return resolveClient(origin, clientHeader, credentials).client !== null;
}

/** True when the caller *declares* a body larger than the client's ceiling. */
function declaredBodyTooLarge(contentLength, maxBytes) {
  const declared = Number.parseInt(contentLength ?? "", 10);
  return Number.isFinite(declared) && declared > maxBytes;
}

/**
 * Read a request body as text, aborting as soon as it exceeds `maxBytes`.
 *
 * `Content-Length` is caller-supplied and may lie or be absent, so the ceiling is also enforced
 * while streaming: nothing larger than `maxBytes` is ever buffered, let alone parsed.
 *
 * @param {ReadableStream|null} body The request body stream.
 * @param {number} maxBytes Ceiling in bytes.
 * @returns {Promise<string>} The decoded body.
 * @throws {Error} With `tooLarge === true` when the ceiling is exceeded.
 */
async function readBoundedText(body, maxBytes) {
  if (!body) return "";
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let size = 0;
  let text = "";
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength ?? value.length ?? 0;
    if (size > maxBytes) {
      await reader.cancel();
      const err = new Error("body too large");
      err.tooLarge = true;
      throw err;
    }
    text += decoder.decode(value, { stream: true });
  }
  return text + decoder.decode();
}

/** Render the locally matched catalogue entries as prompt lines, verbatim and bounded. */
function renderMatches(matches) {
  if (!Array.isArray(matches)) return [];
  return matches
    .filter((m) => m && typeof m === "object")
    .slice(0, MAX_MATCHES)
    .map((m) => {
      const id = String(m.id ?? "").trim();
      const label = String(m.label ?? "").trim();
      const help = String(m.help ?? "").trim();
      const head = [id, label].filter(Boolean).join(" — ");
      const count = Number.isFinite(m.count) ? ` (×${m.count})` : "";
      return `- ${head || "(unnamed entry)"}${count}${help ? `: ${help}` : ""}`;
    });
}

/**
 * Build the system instruction for a log analysis.
 *
 * The catalogue entries were matched locally by `veaf-logs` and are the only authority on what a
 * pattern means: their wording is reproduced as it stands, and anything they do not cover is
 * declared uncatalogued rather than guessed. A wrong culprit costs a pilot his evening and reads
 * exactly like a right one, so "I do not know" is the cheaper failure.
 */
function logAnalysisInstruction(lang, matches) {
  const langName = lang === "en" ? "English" : "French";
  const uncatalogued = lang === "en" ? "pattern not catalogued" : "motif non catalogué";
  const lines = renderMatches(matches);
  const catalogue = lines.length
    ? lines.join("\n")
    : "(no catalogue entry matched this excerpt)";
  return (
    `You are the VEAF DCS log analyst. A local tool (veaf-logs) has already reduced a DCS log to ` +
    `the excerpt below and matched it against its rules catalogue.\n\n` +
    `RULES:\n` +
    `- The catalogue entries below are the ONLY authority on what a pattern means. Reuse their ` +
    `wording as it stands; do not restate them differently.\n` +
    `- Chain the clues, put them in context, and say what the user should do next.\n` +
    `- For anything the catalogue does not cover, say plainly "${uncatalogued}" instead of ` +
    `inventing a cause. Never blame a module, a mission or a script you cannot support with a ` +
    `catalogue entry or with a line of the excerpt itself.\n` +
    `- The excerpt is truncated and filtered: absence of a message is not evidence of absence.\n` +
    `- Answer in ${langName}, concisely, in Markdown.\n\n` +
    `---\n\nCATALOGUE ENTRIES MATCHED LOCALLY:\n${catalogue}`
  );
}

/** Build the Gemini `contents` for a log analysis, truncating an over-long excerpt. */
function buildAnalysisContents(excerpt, question) {
  const raw = typeof excerpt === "string" ? excerpt : "";
  const bounded =
    raw.length > MAX_EXCERPT_CHARS
      ? `${raw.slice(0, MAX_EXCERPT_CHARS)}\n[... excerpt truncated by the Worker ...]`
      : raw;
  const ask = typeof question === "string" ? question.trim() : "";
  const text = ask ? `${ask}\n\n---\n\nLOG EXCERPT:\n${bounded}` : `LOG EXCERPT:\n${bounded}`;
  return [{ role: "user", parts: [{ text }] }];
}

// Named exports for unit testing (unused by the Workers runtime, which only calls the default export).
export {
  latestQuery,
  toGeminiContents,
  upstreamErrorMessage,
  isAllowedClient,
  resolveClient,
  allowRequest,
  degradedAllow,
  declaredBodyTooLarge,
  readBoundedText,
  logAnalysisInstruction,
  buildAnalysisContents,
  CLIENTS,
  MAX_EXCERPT_CHARS,
  DEGRADED_MAX_PER_WINDOW,
};

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin");
    const cors = corsHeaders(origin);
    const sseHeaders = { ...cors, "Content-Type": "text/event-stream" };
    const sseError = (lang, status, message) =>
      new Response(sse({ error: message ?? MESSAGES[lang].badRequest }), {
        status,
        headers: sseHeaders,
      });
    const sseStream = (stream) =>
      new Response(stream, {
        headers: {
          ...cors,
          "Content-Type": "text/event-stream; charset=utf-8",
          "Cache-Control": "no-cache",
          Connection: "keep-alive",
        },
      });

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }

    const url = new URL(request.url);
    const route = url.pathname;
    if (request.method !== "POST" || !ROUTES.has(route)) {
      return new Response("Not found", { status: 404, headers: cors });
    }

    // Admission: an allow-listed browser Origin, or a declared non-browser client mode.
    const { client, spec } = resolveClient(origin, request.headers.get("X-VEAF-Client"), {
      secret: request.headers.get("X-VEAF-Auth"),
      env,
    });
    if (!client || !spec.routes.includes(route)) {
      return new Response("Forbidden", { status: 403, headers: cors });
    }

    // Body ceiling, enforced before anything parses the payload.
    if (declaredBodyTooLarge(request.headers.get("Content-Length"), spec.maxBody)) {
      return new Response("Payload too large", { status: 413, headers: cors });
    }
    let payload;
    try {
      payload = JSON.parse(await readBoundedText(request.body, spec.maxBody));
    } catch (err) {
      return err?.tooLarge
        ? new Response("Payload too large", { status: 413, headers: cors })
        : new Response("Bad request", { status: 400, headers: cors });
    }

    const lang = payload?.lang === "en" ? "en" : "fr";

    // Rate-limit subject: the caller's IP, unless a secret-bearing service carries the quota for
    // its own users (a whole Discord otherwise shares one IP, hence one daily quota).
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    const subjectId = typeof payload?.subject === "string" ? payload.subject.slice(0, 64) : "";
    const subject = spec.secretBinding && subjectId ? `u:${subjectId}` : ip;
    if (!(await allowRequest(env, client, subject))) {
      return sseError(lang, 429, MESSAGES[lang].rateLimited);
    }

    if (route === "/analyze") {
      const excerpt = typeof payload?.excerpt === "string" ? payload.excerpt.trim() : "";
      if (!excerpt) return sseError(lang, 400);
      return sseStream(
        await streamGemini(
          env,
          lang,
          buildAnalysisContents(excerpt, payload?.question),
          logAnalysisInstruction(lang, payload?.matches),
        ),
      );
    }

    const messages = Array.isArray(payload?.messages) ? payload.messages : null;
    const query = messages ? latestQuery(messages) : "";
    if (!messages || !messages.length || !query) {
      return sseError(lang, 400);
    }

    let passages;
    try {
      passages = await retrieveContext(env, lang, query);
    } catch (err) {
      return sseError(lang, err?.status === 429 ? 429 : 502, upstreamErrorMessage(lang, err?.status));
    }

    return sseStream(
      await streamGemini(env, lang, toGeminiContents(messages), systemInstruction(lang, passages)),
    );
  },
};
