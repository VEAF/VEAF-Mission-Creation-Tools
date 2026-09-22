import { test } from "node:test";
import assert from "node:assert/strict";
import {
  chunkMarkdown,
  MAX_CHARS,
  buildLanguageValues,
  KV_KEYS_PER_LANGUAGE,
  KV_WRITE_COST_FILE,
} from "../scripts/build-index.mjs";
import { compareBytes, parseChecks, KV_MISSING_SENTINEL } from "../scripts/verify-index-upload.mjs";
import { l2normalize, topScore, summarise, separation, readVectors } from "../scripts/calibrate-floor.mjs";
import { verdict, parseStream, conversation, askLive, exitCode } from "../scripts/replay-answers.mjs";
import { readFile } from "node:fs/promises";
import worker, {
  latestQuery,
  toGeminiContents,
  upstreamErrorMessage,
  isDailyQuotaFailure,
  MESSAGES,
  isAllowedClient,
  resolveClient,
  allowRequest,
  declaredBodyTooLarge,
  readBoundedText,
  logAnalysisInstruction,
  bugHypothesisInstruction,
  buildAnalysisContents,
  CLIENTS,
  MAX_EXCERPT_CHARS,
  DEGRADED_MAX_PER_WINDOW,
  systemInstruction,
  minSimilarity,
  DEFAULT_MIN_SIMILARITY,
  retrieveContext,
} from "../src/index.js";

/** A KV double: an in-memory map, or a store whose every operation throws (KV outage). */
function fakeKv({ broken = false, values = {} } = {}) {
  const store = new Map(Object.entries(values));
  const boom = () => {
    throw new Error("KV unavailable");
  };
  return {
    store, // exposed so a test can assert what was — or was not — written back
    CHAT_KV: {
      async get(key) {
        return broken ? boom() : (store.get(key) ?? null);
      },
      async put(key, value) {
        return broken ? boom() : void store.set(key, value);
      },
    },
  };
}

/**
 * A full Worker `env`: the KV double above plus the bindings `fetch` reads directly
 * (`GEMINI_API_KEY`, and any Secret a client mode is gated on).
 */
function workerEnv({ kv = {}, ...bindings } = {}) {
  const env = fakeKv({ values: kv });
  return { GEMINI_API_KEY: "test-key", ...bindings, store: env.store, CHAT_KV: env.CHAT_KV };
}

/** Build a request the way a real caller would, so `worker.fetch` sees the actual headers. */
function call(route, { origin, client, secret, headers = {}, body, ip = "203.0.113.1", method = "POST" } = {}) {
  const h = new Headers({ "CF-Connecting-IP": ip, ...headers });
  if (origin) h.set("Origin", origin);
  if (client) h.set("X-VEAF-Client", client);
  if (secret !== undefined) h.set("X-VEAF-Auth", secret);
  const init = { method, headers: h };
  if (body !== undefined) {
    init.body = body instanceof ReadableStream || typeof body === "string" ? body : JSON.stringify(body);
    if (body instanceof ReadableStream) init.duplex = "half";
  }
  return new Request(`https://chat.example${route}`, init);
}

/** The rate-limit keys the Worker wrote — they name the client mode it actually resolved. */
function rateLimitKeys(env) {
  return [...env.store.keys()].filter((k) => k.startsWith("rl:")).sort();
}

/** Wrap a string in a ReadableStream of Uint8Array chunks, as a Request body would arrive. */
function bodyStream(text, chunkSize = 8) {
  const bytes = new TextEncoder().encode(text);
  let offset = 0;
  return new ReadableStream({
    pull(controller) {
      if (offset >= bytes.length) return controller.close();
      controller.enqueue(bytes.slice(offset, offset + chunkSize));
      offset += chunkSize;
    },
  });
}

test("chunkMarkdown merges many tiny heading-sections instead of one chunk each", () => {
  const md = Array.from({ length: 20 }, (_, i) => `## H${i}\n\nshort body ${i}`).join("\n");
  const chunks = chunkMarkdown(md);
  // 20 tiny sections must collapse into far fewer chunks (greedy merge up to MAX_CHARS).
  assert.ok(chunks.length < 20, `expected merging, got ${chunks.length} chunks`);
  assert.ok(chunks.length >= 1);
});

test("chunkMarkdown hard-splits a single oversized paragraph", () => {
  const huge = "x".repeat(MAX_CHARS * 3 + 100); // one paragraph, no blank lines
  const chunks = chunkMarkdown(`# Title\n\n${huge}`);
  assert.ok(chunks.length >= 3, `expected the giant paragraph to be split, got ${chunks.length}`);
});

test("chunkMarkdown never emits a chunk larger than MAX_CHARS", () => {
  const md = `# T\n\n${"a".repeat(MAX_CHARS * 5)}\n\n## S\n\n${"b".repeat(50)}`;
  for (const c of chunkMarkdown(md)) {
    assert.ok(c.length <= MAX_CHARS, `chunk length ${c.length} exceeds MAX_CHARS ${MAX_CHARS}`);
  }
});

// ── the index layout: what a rebuild costs in KV writes ──
// The texts used to be one KV entry per chunk: 1397 writes per rebuild (measured 2026-09-21 over
// doc/) against a free-tier cap of 1000 a day, account-wide and shared with the Worker's own
// rate-limit counters. A single full reindex could not fit in a day. These two tests are the guard
// against that coming back by way of a per-chunk key.

/** A language's worth of fake chunks, with a unit vector each. */
function fakeRecords(n) {
  const cache = {};
  const recs = [];
  for (let i = 0; i < n; i++) {
    const hash = `h${i}`;
    const v = new Array(768).fill(0);
    v[i % 768] = 1;
    cache[hash] = v;
    recs.push({ text: `chunk ${i}`, title: `Page ${i}`, path: `doc/p${i}.md`, hash });
  }
  return { recs, cache };
}

test("the cost file keeps the name the workflow reads", () => {
  // `.github/workflows/docs-chatbot-index.yml` cats this name to build the job summary. A rename
  // here with no test would only surface in CI, after the run has already spent its KV writes.
  assert.equal(KV_WRITE_COST_FILE, "kv-write-cost.txt");
});

test("one language costs two KV keys, whatever the documentation's size", () => {
  assert.equal(KV_KEYS_PER_LANGUAGE, 2, "idx:vec:{lang} and idx:txt:{lang}, and nothing per chunk");
  for (const n of [1, 40, 2000]) {
    const { recs, cache } = fakeRecords(n);
    assert.equal(Object.keys(buildLanguageValues(recs, cache)).length, KV_KEYS_PER_LANGUAGE);
  }
});

test("the two halves line up, and are the same length", () => {
  const { recs, cache } = fakeRecords(5);
  const { vec, txt } = buildLanguageValues(recs, cache);
  assert.equal(vec.length, 5 * 768 * 4, "five 768-dim Float32 vectors");
  const texts = JSON.parse(txt);
  assert.equal(texts.length, 5, "one passage per vector — the Worker refuses any other count");
  assert.deepEqual(texts[3], { text: "chunk 3", title: "Page 3", path: "doc/p3.md" });
  // Position 2 of the blob must hold the unit vector of chunk 2, not of any other.
  const slice = new Float32Array(vec.buffer, vec.byteOffset + 2 * 768 * 4, 768);
  assert.equal(slice[2], 1, "vector i describes passage i");
});

// The embedding cache is keyed on the chunk text alone, so it survives a change of model or of
// EMBED_DIMS and hands back vectors of the wrong width. Measured 2026-09-21 before the guard: a
// 384-wide entry among 768-wide ones produced a blob of exactly the right length and a passage
// array of exactly the right count, so the Worker's length check passed and that passage ranked
// on a half-zeroed vector. The dimension has to be checked where the blob is packed; nothing
// downstream can see it.

test("a cached vector of the wrong width is refused, not zero-padded into the blob", () => {
  const { recs, cache } = fakeRecords(3);
  cache[recs[1].hash] = new Array(384).fill(0.5);
  assert.throws(() => buildLanguageValues(recs, cache), /is 384 wide, expected 768/);
});

test("a wider cached vector is refused too, before it spills into the next chunk's slot", () => {
  const { recs, cache } = fakeRecords(3);
  cache[recs[1].hash] = new Array(1536).fill(0.5);
  assert.throws(() => buildLanguageValues(recs, cache), /is 1536 wide, expected 768/);
});

test("a chunk with no cached vector names the page instead of 'undefined is not iterable'", () => {
  const { recs, cache } = fakeRecords(3);
  delete cache[recs[2].hash];
  assert.throws(() => buildLanguageValues(recs, cache), /no embedding cached for doc\/p2\.md/);
});

test("latestQuery returns the most recent user message", () => {
  const messages = [
    { role: "user", content: "first" },
    { role: "assistant", content: "answer" },
    { role: "user", content: "second" },
  ];
  assert.equal(latestQuery(messages), "second");
});

test("latestQuery ignores assistant messages and empty content", () => {
  assert.equal(latestQuery([{ role: "assistant", content: "hi" }]), "");
  assert.equal(latestQuery([{ role: "user", content: "   " }]), "");
});

test("toGeminiContents maps assistant->model, drops empties, trims history", () => {
  const messages = Array.from({ length: 20 }, (_, i) => ({
    role: i % 2 ? "assistant" : "user",
    content: `m${i}`,
  }));
  messages.push({ role: "user", content: "  " }); // empty, must be dropped
  const out = toGeminiContents(messages);
  assert.ok(out.length <= 12, `history not trimmed: ${out.length}`);
  assert.ok(out.every((m) => m.role === "user" || m.role === "model"));
  assert.ok(out.every((m) => m.parts[0].text.trim().length > 0));
});

/** A Gemini 429 body, shaped like the real one, for the quota id under test. */
function quotaFailure(quotaId, extra = "") {
  return JSON.stringify({
    error: {
      code: 429,
      status: "RESOURCE_EXHAUSTED",
      details: [
        {
          "@type": "type.googleapis.com/google.rpc.QuotaFailure",
          violations: [{ quotaId, quotaMetric: "generativelanguage.googleapis.com/x" }],
        },
      ],
    },
  }).concat(extra);
}

test("isDailyQuotaFailure recognizes a per-day quota id and not a per-minute one", () => {
  assert.equal(isDailyQuotaFailure(quotaFailure("GenerateRequestsPerDayPerProjectPerModel-FreeTier")), true);
  assert.equal(isDailyQuotaFailure(quotaFailure("GenerateRequestsPerMinutePerProjectPerModel-FreeTier")), false);
  assert.equal(isDailyQuotaFailure('{"quotaId":"generate_requests_per_day"}'), true);
});

test("isDailyQuotaFailure treats a long retryDelay as a day-scale wait", () => {
  // Google does not always name the period, but it does say how long to wait. Tens of seconds is
  // a burst limit; anything past five minutes is not something a visitor should sit out.
  assert.equal(isDailyQuotaFailure('{"retryDelay":"41s"}'), false);
  assert.equal(isDailyQuotaFailure('{"retryDelay":"3600s"}'), true);
});

test("isDailyQuotaFailure says no when the body is missing or unreadable", () => {
  // The per-minute wording only under-promises the wait; the daily one announces a rationing that
  // may not have happened. So an unreadable body must not be read as an exhausted day.
  assert.equal(isDailyQuotaFailure(undefined), false);
  assert.equal(isDailyQuotaFailure(""), false);
  assert.equal(isDailyQuotaFailure("<html>502 Bad Gateway</html>"), false);
});

test("upstreamErrorMessage tells a daily exhaustion apart from a per-minute throttle", () => {
  const daily = quotaFailure("GenerateRequestsPerDayPerProjectPerModel-FreeTier");
  const burst = quotaFailure("GenerateRequestsPerMinutePerProjectPerModel-FreeTier");
  for (const lang of ["fr", "en"]) {
    assert.equal(upstreamErrorMessage(lang, 429, daily), MESSAGES[lang].dailyQuota);
    assert.equal(upstreamErrorMessage(lang, 429, burst), MESSAGES[lang].rateLimited);
    assert.equal(upstreamErrorMessage(lang, 429), MESSAGES[lang].rateLimited, "no body: stay on the burst wording");
  }
});

test("the daily message says when the assistant comes back, without Pacific midnight", () => {
  // The reset is midnight Pacific, which no visitor can act on. Both languages must name a local
  // morning hour instead, and neither may promise a wait of "a moment".
  assert.match(MESSAGES.fr.dailyQuota, /9 h/);
  assert.match(MESSAGES.fr.dailyQuota, /matin/);
  assert.match(MESSAGES.en.dailyQuota, /09:00/);
  assert.match(MESSAGES.en.dailyQuota, /morning/);
  for (const lang of ["fr", "en"]) {
    assert.doesNotMatch(MESSAGES[lang].dailyQuota, /Pacific|Pacifique/);
    assert.notEqual(MESSAGES[lang].dailyQuota, MESSAGES[lang].rateLimited);
  }
});

test("upstreamErrorMessage falls back to 'unavailable' for other failures", () => {
  assert.equal(upstreamErrorMessage("fr", 500), "Assistant momentanément indisponible.");
  assert.equal(upstreamErrorMessage("en", 503), "Assistant temporarily unavailable.");
  assert.equal(upstreamErrorMessage("en", undefined), "Assistant temporarily unavailable.");
});

test("isAllowedClient accepts an allow-listed browser Origin", () => {
  assert.equal(isAllowedClient("https://veaf.github.io", null), true);
  assert.equal(isAllowedClient("https://evil.example", null), false);
  assert.equal(isAllowedClient(null, null), false);
});

test("isAllowedClient accepts the CLI header without an Origin", () => {
  assert.equal(isAllowedClient(null, "cli"), true);
  assert.equal(isAllowedClient(null, "nope"), false);
});

test("isAllowedClient allows an allow-listed Origin regardless of the client header", () => {
  assert.equal(isAllowedClient("https://veaf.github.io", "nope"), true);
  assert.equal(isAllowedClient("https://evil.example", "nope"), false);
});

test("a self-declared client header no longer bypasses the Origin allow-list", () => {
  // This used to be admitted: `cliHeader === "cli"` short-circuited the whole allow-list, so any
  // caller claiming to be the CLI got in from any origin at all.
  assert.equal(isAllowedClient("https://evil.example", "cli"), false);
  assert.equal(isAllowedClient("https://evil.example", "logs"), false);
  assert.equal(resolveClient("https://evil.example", "cli").reason, "origin");
});

test("resolveClient maps an allow-listed Origin to the web client, header ignored", () => {
  // An allow-listed page cannot relabel itself to spend another client's quota either.
  assert.equal(resolveClient("https://veaf.github.io", null).client, "web");
  assert.equal(resolveClient("https://veaf.github.io", "logs").client, "web");
});

test("resolveClient accepts the header-declarable non-browser modes", () => {
  assert.equal(resolveClient(null, "cli").client, "cli");
  assert.equal(resolveClient(null, "logs").client, "logs");
  assert.equal(resolveClient(null, "LOGS").client, "logs"); // case/whitespace tolerant
  assert.equal(resolveClient(null, " cli ").client, "cli");
});

test("resolveClient refuses the web mode and unknown modes over the header", () => {
  assert.equal(resolveClient(null, "web").client, null); // web is derived from an Origin only
  assert.equal(resolveClient(null, "constructor").client, null); // no prototype smuggling
  assert.equal(resolveClient(null, "").client, null);
});

test("resolveClient refuses a secret-bearing mode until its Secret is set and matches", () => {
  assert.equal(resolveClient(null, "discord", { secret: "s3cret", env: {} }).reason, "secret");
  assert.equal(resolveClient(null, "discord", { secret: null, env: {} }).reason, "secret");
  const env = { DISCORD_CLIENT_SECRET: "s3cret" };
  assert.equal(resolveClient(null, "discord", { secret: "wrong", env }).reason, "secret");
  assert.equal(resolveClient(null, "discord", { secret: "s3cret", env }).client, "discord");
});

test("every declared client carries its own limits, ceiling and routes", () => {
  const names = Object.keys(CLIENTS);
  assert.deepEqual(names.sort(), ["cli", "discord", "logs", "web"]);
  for (const [name, spec] of Object.entries(CLIENTS)) {
    assert.ok(spec.perWindow > 0, `${name} has no burst limit`);
    assert.ok(spec.perDay > 0, `${name} has no daily limit`);
    assert.ok(spec.maxBody > 0, `${name} has no body ceiling`);
    assert.ok(spec.routes.length > 0, `${name} reaches no route`);
  }
  // Log analysis lives on its own route and its own quota, so it cannot starve the widget.
  assert.deepEqual(CLIENTS.logs.routes, ["/analyze"]);
  assert.deepEqual(CLIENTS.web.routes, ["/chat"]);
  assert.equal(CLIENTS.web.headerDeclarable, false);
});

test("allowRequest counts per client and denies once the KV counter is at the ceiling", async () => {
  const env = fakeKv();
  assert.equal(await allowRequest(env, "cli", "1.2.3.4"), true);
  const atCeiling = fakeKv({
    values: { [`rl:min:cli:1.2.3.4`]: String(CLIENTS.cli.perWindow) },
  });
  assert.equal(await allowRequest(atCeiling, "cli", "1.2.3.4"), false);
  // The daily ceiling is independent of the burst one.
  const dayFull = fakeKv({ values: { [`rl:day:logs:1.2.3.4`]: String(CLIENTS.logs.perDay) } });
  assert.equal(await allowRequest(dayFull, "logs", "1.2.3.4"), false);
});

test("allowRequest keeps each client's counters separate", async () => {
  const env = fakeKv({ values: { "rl:min:web:9.9.9.9": String(CLIENTS.web.perWindow) } });
  assert.equal(await allowRequest(env, "web", "9.9.9.9"), false);
  assert.equal(await allowRequest(env, "logs", "9.9.9.9"), true, "logs must not inherit web's count");
});

test("allowRequest fails closed: a KV outage degrades the limit instead of removing it", async () => {
  const env = fakeKv({ broken: true });
  const ip = `kv-outage-${Date.now()}`; // fresh subject: the degraded counter is per isolate
  let allowed = 0;
  for (let i = 0; i < 10; i++) {
    if (await allowRequest(env, "cli", ip)) allowed++;
  }
  assert.equal(allowed, DEGRADED_MAX_PER_WINDOW, "a KV outage must not lift the rate limit");
  assert.equal(await allowRequest(env, "cli", ip), false);
});

test("allowRequest refuses an undeclared client outright, inherited names included", async () => {
  assert.equal(await allowRequest(fakeKv(), "not-a-client", "1.2.3.4"), false);
  // A bare `CLIENTS[client]` read answered `Object` for these — truthy, and with no quota fields,
  // so every `count >= undefined` comparison was false and the request went through.
  for (const name of ["constructor", "toString", "__proto__", "hasOwnProperty", "valueOf"]) {
    assert.equal(await allowRequest(fakeKv(), name, "1.2.3.4"), false, `${name} is not a client`);
  }
});

test("allowRequest treats an unreadable counter as the ceiling and does not rewrite it", async () => {
  // `parseInt("NaN")` is `NaN`, and `NaN >= perDay` is false — so a poisoned counter used to open
  // the gate, and `String(NaN + 1)` wrote `"NaN"` straight back with a fresh 24 h TTL, keeping it
  // open for good. Measured before the fix: 10 of 200 requests admitted, value still "NaN".
  for (const poison of ["NaN", "abc", "-1", "1e3", "9.5"]) {
    const day = fakeKv({ values: { "rl:day:cli:7.7.7.7": poison } });
    assert.equal(await allowRequest(day, "cli", "7.7.7.7"), false, `daily counter "${poison}"`);
    const min = fakeKv({ values: { "rl:min:cli:7.7.7.7": poison } });
    assert.equal(await allowRequest(min, "cli", "7.7.7.7"), false, `burst counter "${poison}"`);
  }
  const env = fakeKv({ values: { "rl:day:cli:7.7.7.7": "NaN" } });
  assert.equal(await allowRequest(env, "cli", "7.7.7.7"), false);
  assert.equal(env.store.get("rl:day:cli:7.7.7.7"), "NaN", "the poisoned value must not be refreshed");
  assert.equal(env.store.has("rl:min:cli:7.7.7.7"), false, "a refused request writes no counter");
});

test("allowRequest still reads an absent or empty counter as zero", async () => {
  const env = fakeKv({ values: { "rl:min:cli:7.7.7.9": "" } });
  assert.equal(await allowRequest(env, "cli", "7.7.7.9"), true);
  assert.equal(env.store.get("rl:min:cli:7.7.7.9"), "1");
});

test("declaredBodyTooLarge rejects an over-ceiling Content-Length, tolerates a missing one", () => {
  assert.equal(declaredBodyTooLarge("20000", 16 * 1024), true);
  assert.equal(declaredBodyTooLarge("100", 16 * 1024), false);
  assert.equal(declaredBodyTooLarge(null, 16 * 1024), false); // absent: the stream ceiling catches it
  assert.equal(declaredBodyTooLarge("not-a-number", 16 * 1024), false);
});

test("readBoundedText aborts a body that lies about its size", async () => {
  const payload = "x".repeat(5000);
  await assert.rejects(
    () => readBoundedText(bodyStream(payload, 256), 1024),
    (err) => err.tooLarge === true,
  );
});

test("readBoundedText returns a body under the ceiling, multi-byte characters intact", async () => {
  const payload = JSON.stringify({ excerpt: "réussi — ok", matches: [] });
  assert.equal(await readBoundedText(bodyStream(payload, 5), 4096), payload);
  assert.equal(await readBoundedText(null, 4096), "");
});

test("logAnalysisInstruction reproduces the catalogue wording and forbids guessing", () => {
  const help = "Modules tiers dont le modèle de dégâts n'est pas au format attendu. Cosmétique.";
  const out = logAnalysisInstruction("fr", [{ id: "damage-model", label: "Moteur", help, count: 3 }]);
  assert.ok(out.includes(help), "the catalogue help text must be passed through verbatim");
  assert.ok(out.includes("damage-model"));
  assert.ok(out.includes("×3"));
  assert.ok(out.includes("motif non catalogué"), "FR must instruct the uncatalogued wording");
  assert.ok(/ONLY authority/.test(out));
});

test("logAnalysisInstruction survives no match at all and bounds the entry list", () => {
  const empty = logAnalysisInstruction("en", undefined);
  assert.ok(empty.includes("no catalogue entry matched"));
  assert.ok(empty.includes("pattern not catalogued"));
  const many = logAnalysisInstruction(
    "en",
    Array.from({ length: 200 }, (_, i) => ({ id: `e${i}`, help: `h${i}` })),
  );
  assert.ok(!many.includes("e199"), "the catalogue block must be bounded");
});

test("bugHypothesisInstruction asks for a conclusion, not an investigation", () => {
  const out = bugHypothesisInstruction("en");
  assert.ok(/already prepared/.test(out), "the model must know the work was done for it");
  assert.ok(/Conclude on what is in front of you/.test(out));
  assert.ok(/not enough to conclude/.test(out), "refusing to conclude must be an available answer");
  assert.ok(/Never invent a path/.test(out));
  assert.ok(/data, not instruction/.test(out), "the report is a public intake channel");
});

test("bugHypothesisInstruction answers in the reporter's language and stays a guess", () => {
  const fr = bugHypothesisInstruction("fr");
  assert.ok(fr.includes("pas de quoi conclure"), "FR must instruct the FR refusal wording");
  assert.ok(/in French/.test(fr));
  assert.ok(fr.includes("never as a "), "a hypothesis phrased as a diagnosis closes real bugs");
  assert.ok(fr.includes("diagnosis"));
});

test("buildAnalysisContents truncates an over-long excerpt and keeps the question", () => {
  const [content] = buildAnalysisContents("y".repeat(MAX_EXCERPT_CHARS * 2), "  why does it crash? ");
  assert.equal(content.role, "user");
  const text = content.parts[0].text;
  assert.ok(text.startsWith("why does it crash?"));
  assert.ok(text.includes("excerpt truncated by the Worker"));
  assert.ok(text.length < MAX_EXCERPT_CHARS * 2, "the excerpt must not be forwarded whole");
});

test("buildAnalysisContents works without a question", () => {
  const [content] = buildAnalysisContents("ERROR something", null);
  assert.ok(content.parts[0].text.includes("ERROR something"));
});

// ---------------------------------------------------------------------------------------------
// Wiring: everything below drives the real entry point, `worker.fetch(request, env)`.
//
// The tests above exercise the handlers in isolation, which is exactly how green bugs ship on this
// repository: the handler is right and nothing checks that it is still plugged in. What these lock
// is the plumbing — that `X-VEAF-Auth` is the header actually read, that `spec.routes` really
// filters, that `spec.maxBody` is the ceiling handed to `readBoundedText`, that the call site
// resolves a *mode* rather than a boolean, and that `/analyze` is a declared route.
//
// The lever used throughout: the rate-limit keys the Worker writes name the mode it resolved, and
// a request that reaches a *later* rejection (400/413/429) is one that got past admission.
// ---------------------------------------------------------------------------------------------

test("fetch: the widget's allow-listed Origin resolves to the web client", async () => {
  const env = workerEnv();
  const res = await worker.fetch(
    call("/chat", { origin: "https://veaf.github.io", body: { lang: "fr" } }),
    env,
  );
  // 400, not 403: admission passed and the empty message list is what failed.
  assert.equal(res.status, 400);
  assert.equal(res.headers.get("Access-Control-Allow-Origin"), "https://veaf.github.io");
  assert.deepEqual(rateLimitKeys(env), ["rl:day:web:203.0.113.1", "rl:min:web:203.0.113.1"]);
});

test("fetch: X-VEAF-Client selects the cli mode when there is no Origin", async () => {
  const env = workerEnv();
  const res = await worker.fetch(call("/chat", { client: "cli", body: { lang: "fr" } }), env);
  assert.equal(res.status, 400);
  assert.deepEqual(rateLimitKeys(env), ["rl:day:cli:203.0.113.1", "rl:min:cli:203.0.113.1"]);
});

test("fetch: a hostile Origin is refused even while it declares the cli header", async () => {
  // The bypass this whole change exists to close, checked where it was actually exploitable.
  const env = workerEnv();
  const res = await worker.fetch(
    call("/chat", {
      origin: "https://evil.example",
      client: "cli",
      body: { lang: "fr", messages: [{ role: "user", content: "hi" }] },
    }),
    env,
  );
  assert.equal(res.status, 403);
  assert.equal(res.headers.get("Access-Control-Allow-Origin"), null, "no CORS grant either");
  assert.deepEqual(rateLimitKeys(env), [], "a refused caller never reaches the rate limiter");
});

test("fetch: each mode only reaches the routes its spec declares", async () => {
  const analyze = { lang: "fr", excerpt: "ERROR boom" };
  const chat = { lang: "fr", messages: [{ role: "user", content: "hi" }] };
  const refused = [
    ["/analyze", { origin: "https://veaf.github.io", body: analyze }], // web is /chat only
    ["/analyze", { client: "cli", body: analyze }],
    ["/chat", { client: "logs", body: chat }], // logs is /analyze only
  ];
  for (const [route, opts] of refused) {
    const res = await worker.fetch(call(route, opts), workerEnv());
    assert.equal(res.status, 403, `${route} must be out of scope for ${JSON.stringify(opts)}`);
  }

  // ...and /analyze really is a declared route for `logs`: an empty excerpt earns a 400, not a 404.
  const env = workerEnv();
  const admitted = await worker.fetch(
    call("/analyze", { client: "logs", body: { lang: "fr", excerpt: "  " } }),
    env,
  );
  assert.equal(admitted.status, 400);
  assert.deepEqual(rateLimitKeys(env), ["rl:day:logs:203.0.113.1", "rl:min:logs:203.0.113.1"]);

  // An undeclared path is a 404, decided before admission runs at all.
  const unknown = await worker.fetch(call("/explain", { client: "logs", body: analyze }), workerEnv());
  assert.equal(unknown.status, 404);
});

test("fetch: the body ceiling is the one the resolved client declares", async () => {
  const payload = "x".repeat(100 * 1024); // over cli's 64 KiB, under logs' 128 KiB

  const declared = await worker.fetch(call("/chat", { client: "cli", body: payload }), workerEnv());
  assert.equal(declared.status, 413, "a declared length above CLIENTS.cli.maxBody is refused");

  const roomier = await worker.fetch(call("/analyze", { client: "logs", body: payload }), workerEnv());
  assert.equal(roomier.status, 400, "the same size fits CLIENTS.logs.maxBody, so it is parsed");

  // A stream body carries no Content-Length, so only the streaming ceiling can catch it.
  const streamed = await worker.fetch(
    call("/chat", { client: "cli", body: bodyStream(payload, 4096) }),
    workerEnv(),
  );
  assert.equal(streamed.status, 413, "an undeclared body length is still bounded while streaming");
});

test("fetch: the discord mode is gated on X-VEAF-Auth matching the configured Secret", async () => {
  const body = { lang: "fr", excerpt: "", subject: "pilot-42" };
  const send = (env, opts) => worker.fetch(call("/analyze", { client: "discord", body, ...opts }), env);
  const configured = () => workerEnv({ DISCORD_CLIENT_SECRET: "s3cret" });

  // 1. Secret never set: groundwork is a closed door, not an open one.
  assert.equal((await send(workerEnv(), { secret: "s3cret" })).status, 403);
  // 2. Set but empty: an empty Secret must not be matched by an empty header.
  assert.equal((await send(workerEnv({ DISCORD_CLIENT_SECRET: "" }), { secret: "" })).status, 403);
  // 3. Set, wrong secret presented.
  assert.equal((await send(configured(), { secret: "wrong" })).status, 403);
  // 4. Right secret, wrong header: X-VEAF-Auth is the header that is read, and only it.
  assert.equal((await send(configured(), { headers: { Authorization: "s3cret" } })).status, 403);

  // 5. Right secret in X-VEAF-Auth: admitted (400 on the empty excerpt), and the quota is carried
  //    per Discord user rather than per IP — a whole Discord sits behind one address.
  const env = configured();
  assert.equal((await send(env, { secret: "s3cret" })).status, 400);
  assert.deepEqual(rateLimitKeys(env), ["rl:day:discord:u:pilot-42", "rl:min:discord:u:pilot-42"]);
});

test("fetch: a caller at its daily ceiling gets a localized 429", async () => {
  const env = workerEnv({ kv: { "rl:day:cli:203.0.113.9": String(CLIENTS.cli.perDay) } });
  const res = await worker.fetch(
    call("/chat", {
      client: "cli",
      ip: "203.0.113.9",
      body: { lang: "en", messages: [{ role: "user", content: "hi" }] },
    }),
    env,
  );
  assert.equal(res.status, 429);
  assert.match(await res.text(), /back in a minute/);
});

test("fetch: an exhausted daily Gemini quota reaches the caller as the daily message", async () => {
  // The wiring, not the mapping: the upstream body has to be read and carried all the way to the
  // SSE payload, or the visitor gets "try again shortly" for a wall that stands until morning.
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(quotaFailure("GenerateRequestsPerDayPerProjectPerModel-FreeTier"), { status: 429 });
  try {
    const res = await worker.fetch(
      call("/chat", {
        origin: "https://veaf.github.io",
        ip: "203.0.113.44",
        body: { lang: "fr", messages: [{ role: "user", content: "comment builder ?" }] },
      }),
      workerEnv(),
    );
    assert.equal(res.status, 429);
    const body = await res.text();
    assert.match(body, /allocation de questions pour la journée/);
    assert.match(body, /9 h/);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test("fetch: /analyze streams the answer back as SSE, framed by the catalogue", async () => {
  const upstream = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    upstream.push({ url: String(url), body: JSON.parse(init.body) });
    const chunk = JSON.stringify({ candidates: [{ content: { parts: [{ text: "voilà" }] } }] });
    return new Response(`data: ${chunk}\n\n`, { status: 200 });
  };
  try {
    const res = await worker.fetch(
      call("/analyze", {
        client: "logs",
        body: {
          lang: "fr",
          excerpt: "ERROR boom",
          matches: [{ id: "damage-model", help: "Cosmétique." }],
        },
      }),
      workerEnv(),
    );
    assert.equal(res.status, 200);
    assert.match(res.headers.get("Content-Type"), /text\/event-stream/);
    const text = await res.text();
    assert.match(text, /data: \{"text":"voilà"\}/);
    assert.match(text, /data: \[DONE\]/);

    assert.equal(upstream.length, 1, "exactly one upstream call");
    const instruction = upstream[0].body.systemInstruction.parts[0].text;
    assert.ok(instruction.includes("Cosmétique."), "the catalogue wording frames the answer");
    assert.ok(upstream[0].body.contents[0].parts[0].text.includes("ERROR boom"));
  } finally {
    globalThis.fetch = realFetch;
  }
});

// --- Relevance floor -------------------------------------------------------
// A ranking-only retrieval always returns its top K, so "a passage was found" never meant "the
// answer was found". The model was handed six confident-looking excerpts for a question the docs do
// not cover and answered from them. These cover both halves of the remedy: the floor that drops
// plainly unrelated passages, and the instruction that makes the model judge what survives.

test("an out-of-range or unparseable similarity floor falls back to the default", () => {
  assert.equal(minSimilarity({}), DEFAULT_MIN_SIMILARITY);
  assert.equal(minSimilarity({ MIN_SIMILARITY: "not a number" }), DEFAULT_MIN_SIMILARITY);
  assert.equal(minSimilarity({ MIN_SIMILARITY: "0" }), DEFAULT_MIN_SIMILARITY, "0 would disable it");
  assert.equal(minSimilarity({ MIN_SIMILARITY: "1" }), DEFAULT_MIN_SIMILARITY, "1 would gag it");
  assert.equal(minSimilarity({ MIN_SIMILARITY: "-0.5" }), DEFAULT_MIN_SIMILARITY);
});

test("a sane similarity floor is honoured", () => {
  assert.equal(minSimilarity({ MIN_SIMILARITY: "0.62" }), 0.62);
});

test("the default floor is low enough to be a floor, not a gag", () => {
  assert.ok(DEFAULT_MIN_SIMILARITY > 0 && DEFAULT_MIN_SIMILARITY < 0.5);
});

test("with passages, the model is told the search may have missed", () => {
  const instruction = systemInstruction("fr", "# Une page\n\ndu texte");
  assert.ok(instruction.includes("du texte"), "the passages are still injected");
  assert.match(instruction, /not a guaranteed answer/, "the excerpts are framed as best matches");
  assert.match(instruction, /Never invent/, "inventing a setting or command is ruled out");
  assert.match(instruction, /French/, "the reply language is still pinned");
});

test("with no passage, the model is forbidden to answer from its own knowledge", () => {
  const instruction = systemInstruction("en", "");
  assert.match(instruction, /found nothing relevant/);
  assert.match(instruction, /Do NOT answer from your own knowledge/);
  assert.match(instruction, /Discord/, "the visitor is sent somewhere a human can help");
  assert.match(instruction, /English/);
});

// A missing index and a question outside the documentation must NOT look alike. Dropping passages
// below the floor made an empty result ordinary, and that very nearly turned a broken deployment
// into a polite "the documentation does not cover that" on every question, with nothing to alert
// anyone. Each test uses its own `lang` key because the vector cache is module-level.

/**
 * Fake a Gemini embedding endpoint returning `vector`, and a KV holding the given index.
 *
 * The index is two keys: the vector blob and the passage array, in the same order. `texts`
 * defaults to one entry per vector so the halves agree — a disagreement is its own test.
 */
function retrievalEnv(lang, vector, texts) {
  const buf = new Float32Array(vector);
  const count = Math.floor(buf.length / 768);
  const passages = texts ?? Array.from({ length: count }, (_, i) => ({ title: `T${i}`, text: "body" }));
  const store = new Map(
    Object.entries({ [`idx:vec:${lang}`]: buf.buffer, [`idx:txt:${lang}`]: passages }),
  );
  return {
    GEMINI_API_KEY: "test-key",
    CHAT_KV: { async get(key) { return store.get(key) ?? null; } },
  };
}

function withFakeEmbedding(vector, fn) {
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(JSON.stringify({ embedding: { values: vector } }), { status: 200 });
  return fn().finally(() => {
    globalThis.fetch = realFetch;
  });
}

test("vectors present but no text behind them is an error, not an empty answer", async () => {
  // One indexed vector pointing the same way as the query: it scores 1.0 and clears any floor.
  // Its entry in the passage array is empty — a build that produced a hole.
  const unit = new Array(768).fill(0);
  unit[0] = 1;
  await withFakeEmbedding(unit, async () => {
    await assert.rejects(
      () => retrieveContext(retrievalEnv("xa", unit, [null]), "xa", "anything"),
      /no passages retrieved/,
      "a broken index must surface, not read as 'not documented'",
    );
  });
});

test("a text value that is not a passage array is refused", async () => {
  // An absent key means the old per-chunk layout (see the transition tests below). A key that is
  // present but holds something else is a corrupt index, and must not be read as either.
  const unit = new Array(768).fill(0);
  unit[0] = 1;
  const buf = new Float32Array(unit);
  const store = new Map([
    ["idx:vec:xd", buf.buffer],
    ["idx:txt:xd", { passages: ["not an array"] }],
  ]);
  const env = {
    GEMINI_API_KEY: "test-key",
    CHAT_KV: { async get(key) { return store.get(key) ?? null; } },
  };
  await withFakeEmbedding(unit, async () => {
    await assert.rejects(() => retrieveContext(env, "xd", "anything"), /no passages for xd/);
  });
});

test("halves of different lengths are refused instead of answering off by one", async () => {
  // Two vectors, one passage: the layout this replaced could reach that state by caching an old
  // blob against a freshly uploaded text set, and it served the wrong passage without an error.
  const two = new Array(768 * 2).fill(0);
  two[0] = 1;
  await withFakeEmbedding(new Array(768).fill(0), async () => {
    await assert.rejects(
      () => retrieveContext(retrievalEnv("xe", two, [{ title: "T", text: "body" }]), "xe", "q"),
      /disagree for xe: 2 vectors, 1 texts/,
    );
  });
});

test("a question unrelated to every passage yields an empty context rather than an error", async () => {
  // The indexed vector is orthogonal to the query, so it scores 0 and cannot clear the floor.
  const indexed = new Array(768).fill(0);
  indexed[0] = 1;
  const query = new Array(768).fill(0);
  query[1] = 1;
  await withFakeEmbedding(query, async () => {
    const passages = await retrieveContext(
      retrievalEnv("xb", indexed, [{ title: "T", text: "body" }]),
      "xb",
      "something else entirely",
    );
    assert.equal(passages, "", "off-topic is an ordinary outcome the caller explains");
    assert.match(systemInstruction("fr", passages), /found nothing relevant/);
  });
});

// TRANSITION (remove with the shim in loadIndex): the Worker deploys on a merge and the index is
// rebuilt by a separate workflow with no ordering between them, so the new code reaches production
// before `idx:txt:{lang}` exists — and a rebuild that fails on the KV quota leaves it there. Five
// rebuilds had already failed on quota the day this shipped, so without the fallback the assistant
// would have answered 502 to every question for hours.
test("with no text blob yet, the old per-chunk keys still answer", async () => {
  const unit = new Array(768).fill(0);
  unit[0] = 1;
  const buf = new Float32Array(unit);
  const legacy = new Map([
    ["idx:vec:xf", buf.buffer],
    ["idx:txt:xf:0", { title: "Coalitions", text: "body" }],
  ]);
  const env = {
    GEMINI_API_KEY: "test-key",
    CHAT_KV: { async get(key) { return legacy.get(key) ?? null; } },
  };
  await withFakeEmbedding(unit, async () => {
    const passages = await retrieveContext(env, "xf", "a matching question");
    assert.match(passages, /Coalitions/, "the pre-2026-09-21 layout is still served");
  });
});

test("with neither layout present, a broken index still surfaces", async () => {
  const unit = new Array(768).fill(0);
  unit[0] = 1;
  const buf = new Float32Array(unit);
  const env = {
    GEMINI_API_KEY: "test-key",
    CHAT_KV: { async get(key) { return key === "idx:vec:xg" ? buf.buffer : null; } },
  };
  await withFakeEmbedding(unit, async () => {
    await assert.rejects(
      () => retrieveContext(env, "xg", "anything"),
      /no passages retrieved/,
      "the fallback must not turn a missing index into a polite 'not documented'",
    );
  });
});

test("a passage above the floor is still injected", async () => {
  const unit = new Array(768).fill(0);
  unit[0] = 1;
  await withFakeEmbedding(unit, async () => {
    const passages = await retrieveContext(
      retrievalEnv("xc", unit, [{ title: "Coalitions", text: "body" }]),
      "xc",
      "a matching question",
    );
    assert.match(passages, /Coalitions/);
    assert.match(passages, /body/);
  });
});

// ── verify-index-upload: a green run must mean the bytes are in the namespace ──
// These cover the failure the upload step could not tell apart from success for six weeks:
// it wrote to wrangler's local store, printed `Success!`, and the live index stayed frozen.

test("a read-back that never happened is a problem, not a pass", () => {
  assert.match(compareBytes("vectors (fr)", Buffer.from("abc"), null), /nothing came back/);
});

test("an empty read-back is a problem", () => {
  assert.match(compareBytes("vectors (fr)", Buffer.from("abc"), Buffer.alloc(0)), /0 bytes/);
});

test("wrangler's missing-key output is recognised, not read as a value", () => {
  // `kv key get` exits 0 and prints this to stdout for an absent key, so the shell cannot tell.
  const problem = compareBytes("texts (fr)", Buffer.alloc(40), Buffer.from(`${KV_MISSING_SENTINEL}
`));
  assert.match(problem, /the key is not in the namespace/);
  assert.doesNotMatch(problem, /older index/, "an absent key is not a stale index");
});

test("a stale index of a different size is named as stale", () => {
  const problem = compareBytes("vectors (fr)", Buffer.alloc(40), Buffer.alloc(24));
  assert.match(problem, /holds 24 bytes, the build produced 40/);
  assert.match(problem, /older index is still in place/);
});

test("same length but different bytes still fails", () => {
  const problem = compareBytes("vectors (fr)", Buffer.from([1, 2, 3]), Buffer.from([1, 2, 4]));
  assert.match(problem, /different bytes/);
});

test("identical bytes are the only thing that passes", () => {
  assert.equal(compareBytes("vectors (fr)", Buffer.from([1, 2, 3]), Buffer.from([1, 2, 3])), null);
});

test("the checks are parsed as triples, and a truncated one is refused", () => {
  assert.deepEqual(parseChecks(["--vec", "fr", "a.bin", "b.bin"]), [
    { kind: "--vec", lang: "fr", built: "a.bin", readBack: "b.bin" },
  ]);
  assert.throws(() => parseChecks(["--vec", "fr", "a.bin"]), /needs three values/);
  assert.throws(() => parseChecks(["--oops", "fr", "a", "b"]), /expected --vec or --txt/);
});

test("asking for no check at all is refused rather than passing vacuously", () => {
  assert.throws(() => parseChecks([]), /no checks requested/);
});

test("a triple cut short by the next flag is refused, not read as a file named --txt", () => {
  assert.throws(
    () => parseChecks(["--vec", "fr", "a.bin", "--txt", "fr", "b.json", "c.json"]),
    /needs three values/,
  );
});

// ── calibrate-floor: the maths the measurement rests on ──
// A calibration that scores wrongly produces a number that looks just as authoritative, so the
// parts that can be checked without the Gemini API are checked here.

test("l2normalize gives a unit vector, and leaves a zero vector alone", () => {
  const unit = l2normalize([3, 4]);
  assert.ok(Math.abs(Math.hypot(unit[0], unit[1]) - 1) < 1e-6);
  assert.deepEqual(Array.from(l2normalize([0, 0])), [0, 0]);
});

test("topScore is the cosine with the best chunk, not with the first or the last", () => {
  const dims = 2;
  // Three chunks: orthogonal, opposite, then a close match — the best must win from any position.
  const vectors = Float32Array.from([0, 1, -1, 0, 1, 0]);
  const query = l2normalize([1, 0]);
  assert.ok(Math.abs(topScore(query, vectors, dims) - 1) < 1e-6);
});

test("a truncated index blob is refused rather than scored on garbage", () => {
  // 5 floats cannot be whole 2-wide vectors: a half-downloaded file must not quietly score.
  assert.throws(() => topScore(Float32Array.from([1, 0]), Float32Array.from([1, 0, 0, 1, 1]), 2), /not a multiple/);
});

test("summarise reports the range and the median", () => {
  assert.deepEqual(summarise([0.4, 0.2, 0.6]), { n: 3, min: 0.2, median: 0.4, max: 0.6 });
  assert.deepEqual(summarise([0.2, 0.4]), { n: 2, min: 0.2, median: 0.3, max: 0.4 });
});

test("separation says the clouds part when they do", () => {
  const s = separation([0.7, 0.8], [0.3, 0.4]);
  assert.equal(s.separable, true);
  assert.equal(s.overlap, 0);
});

test("separation counts the overlap when they do not part", () => {
  // One undocumented question scores above the weakest documented one.
  const s = separation([0.5, 0.8], [0.3, 0.6]);
  assert.equal(s.separable, false);
  assert.ok(s.overlap > 0, "an overlap must be counted, not rounded away");
});

test("separation refuses to judge an empty group instead of calling it separable", () => {
  assert.throws(() => separation([0.5, 0.6], []), /undocumented group is empty/);
  assert.throws(() => separation([], [0.2]), /documented group is empty/);
  assert.throws(() => separation([], []), /documented and undocumented group is empty/);
});

test("a blob that is not a whole number of floats is refused, not rounded down", () => {
  // Measured: `new Float32Array(buf.buffer, 0, 4098/4)` truncates to 1024 floats without a word.
  assert.throws(() => readVectors(Buffer.alloc(4098)), /not a whole number of floats/);
  assert.throws(() => readVectors(Buffer.alloc(0)), /is empty/);
  assert.equal(readVectors(Buffer.alloc(8)).length, 2);
});

test("readVectors copes with a Buffer that is not 4-aligned", () => {
  // Node pools small reads, so a Buffer's byteOffset can be anything; reinterpreting in place throws.
  const pool = Buffer.alloc(16);
  const misaligned = pool.subarray(2, 10);
  assert.equal(misaligned.byteOffset % 4, 2, "the fixture must actually be misaligned");
  assert.equal(readVectors(misaligned).length, 2);
});

// --- Answering the need ----------------------------------------------------
// A question arrives wrapped in the approach its asker already took, and the assistant used to stay
// inside that wrapping: asked how to simplify a Lua block setting three booleans, it answered
// correctly about the Lua callback and never said four lines of `mission.yaml` replaced the whole
// block — with the excerpt saying exactly that in its own context and cited in its own sources.
//
// What a unit test can reach here is the instruction, not the answer. The answer is a model's, and
// it is replayed against the live assistant by `scripts/replay-answers.mjs`; these pin the rule's
// two halves, since the fix is worth nothing if it becomes "always suggest YAML".

test("with passages, the model is told to answer the need and not only the phrasing", () => {
  const instruction = systemInstruction("fr", "# Une page\n\ndu texte");
  assert.match(instruction, /Answer the need, not only the question as it is phrased/);
  assert.match(instruction, /simpler supported way/, "the simple path is what it must surface");
  assert.match(instruction, /still answer what was asked/, "the question asked is still answered");
});

test("the simpler path is offered only when an excerpt states it", () => {
  const instruction = systemInstruction("en", "# A page\n\nsome text");
  assert.match(instruction, /only when an excerpt states that simpler way/);
  assert.match(instruction, /never from your own knowledge/);
  // The guardrail half: a setting documented as reachable only by the long route keeps it. Without
  // this the fix trades one wrong default for a worse one — `aircraftType` is a keyed value the
  // build refuses in YAML, so that answer would not merely read badly, it would not work.
  assert.match(instruction, /never when the excerpts say it does not cover their case/);
  assert.match(instruction, /reachable only by the longer route/);
});

test("with no passage, nothing invites the model to volunteer a simpler path", () => {
  // Nothing was retrieved, so there is no excerpt to ground a "there is a simpler way" in, and the
  // empty-handed instruction must stay what it is: a refusal, not an invitation to be helpful.
  const instruction = systemInstruction("fr", "");
  assert.doesNotMatch(instruction, /simpler supported way/);
  assert.match(instruction, /Do NOT answer from your own knowledge/);
});

// --- Replaying the answers against the live assistant ----------------------
// The script itself needs a deployed Worker and a model, so what is tested here is its judgement:
// the verdict, the stream parsing, and the shape of the declared cases.

test("a verdict names what was missing, not merely that something was", () => {
  const spec = { expectAll: ["mission.yaml", "settings"], forbid: ["aircraftType:"] };
  assert.deepEqual(verdict("Mettez ça dans mission.yaml sous settings:", spec).missing, []);
  assert.equal(verdict("Mettez ça dans mission.yaml sous settings:", spec).ok, true);
  const short = verdict("Utilisez le callback Lua.", spec);
  assert.equal(short.ok, false);
  assert.deepEqual(short.missing, ["mission.yaml", "settings"]);
});

test("a forbidden marker fails a case that is otherwise complete", () => {
  // The guardrail, as the script sees it: a YAML block for `aircraftType` does not work at all.
  const spec = { expectAny: ["callback"], forbid: ["aircraftType:"] };
  const answer = "Utilisez le callback Lua, ou bien :\n```yaml\naircraftType:\n  UH-1H: 8\n```";
  const outcome = verdict(answer, spec);
  assert.equal(outcome.ok, false);
  assert.deepEqual(outcome.forbidden, ["aircraftType:"]);
});

test("an empty expectAny requires nothing instead of satisfying nothing", () => {
  // `[].some()` is false, so the naive reading fails every case that only declares `expectAll`.
  assert.equal(verdict("n'importe quoi", { expectAll: [] }).ok, true);
  assert.equal(verdict("n'importe quoi", { expectAny: [] }).ok, true);
});

test("markers are matched whatever the case of the answer", () => {
  assert.equal(verdict("Mission.YAML", { expectAll: ["mission.yaml"] }).ok, true);
});

test("the Worker's own error inside a 200 stream is not read as an empty answer", () => {
  // A spent daily allowance arrives this way. Reported as "could not ask", never as a failed case.
  const body = 'data: {"text":"Pour"}\n\ndata: {"error":"allocation épuisée"}\n\ndata: [DONE]\n\n';
  const parsed = parseStream(body);
  assert.equal(parsed.text, "Pour");
  assert.equal(parsed.error, "allocation épuisée");
});

test("a malformed frame does not end an otherwise good stream", () => {
  const body = 'data: {"text":"a"}\n\ndata: not json\n\n: comment\n\ndata: {"text":"b"}\n\ndata: [DONE]\n\n';
  assert.equal(parseStream(body).text, "ab");
  assert.equal(parseStream(body).error, null);
});

test("the question is the last user turn and carries nothing else", () => {
  // The Worker embeds that turn verbatim; an instruction joined to it would be embedded with it.
  const turns = conversation("comment simplifier ce bloc ?");
  assert.equal(turns.length, 1);
  assert.deepEqual(turns.at(-1), { role: "user", content: "comment simplifier ce bloc ?" });
});

test("the declared cases cover both directions of the defect", async () => {
  const file = new URL("../scripts/answer-cases.json", import.meta.url);
  const { cases } = JSON.parse(await readFile(file, "utf8"));
  const byId = new Map(cases.map((c) => [c.id, c]));
  for (const spec of cases) {
    assert.ok(spec.question.trim(), `${spec.id} asks something`);
    assert.ok(["fr", "en"].includes(spec.lang), `${spec.id} declares a language`);
    assert.ok(spec.why.trim(), `${spec.id} says what it is for`);
    assert.ok(
      (spec.expectAll ?? []).length || (spec.expectAny ?? []).length,
      `${spec.id} asserts something about the answer`,
    );
  }
  // Named rather than counted: a case set that lost the guardrail would still have three cases.
  const simple = byId.get("csar-booleans-fr");
  assert.ok(simple.expectAll.includes("mission.yaml"), "the simple path must be named");
  const keyed = byId.get("csar-aircrafttype-fr");
  assert.ok(keyed.forbid.includes("aircraftType:"), "the keyed setting must not be offered in YAML");
  assert.ok(keyed.expectAny.includes("csar.initialize"), "the callback stays the answer there");
});

test("askLive declares a User-Agent, which Cloudflare refuses the request without", () => {
  // Measured 2026-09-22: Node's default client sends none and every call came back 403 with body
  // `error code: 1010` — a managed rule, before the Worker runs, so nothing in its log says so. It
  // reads exactly like the Worker's own client-admission 403, which is why this is pinned.
  let seen = null;
  const fake = async (url, init) => {
    seen = init;
    return { ok: true, status: 200, async text() { return 'data: [DONE]\n\n'; } };
  };
  return askLive("https://example.invalid/chat", { lang: "fr", question: "q" }, fake).then(() => {
    assert.ok(seen.headers["User-Agent"], "a User-Agent is sent");
    assert.equal(seen.headers["X-VEAF-Client"], "cli", "the secret-free client mode is declared");
    assert.ok(!("X-VEAF-Auth" in seen.headers), "no secret is needed, and none is invented");
  });
});

test("a non-200 is reported as an unaskable case, not as a wrong answer", async () => {
  const fake = async () => ({ ok: false, status: 429, async text() { return "Too Many Requests"; } });
  const result = await askLive("https://example.invalid/chat", { lang: "fr", question: "q" }, fake);
  assert.equal(result.status, 429);
  assert.match(result.error, /HTTP 429/);
  assert.equal(result.text, "");
});

test("a run that measured nothing does not exit like a green one", () => {
  // The failure this repository has already paid for twice: a check that goes green having observed
  // nothing. On a spent-allowance day every case is unavailable, and 0 would certify the fix.
  assert.equal(exitCode({ failed: 0, unavailable: 3, total: 3 }), 2);
  assert.equal(exitCode({ failed: 0, unavailable: 2, total: 3 }), 0, "one real answer is a measurement");
  assert.equal(exitCode({ failed: 1, unavailable: 2, total: 3 }), 1, "a failure outranks an outage");
  assert.equal(exitCode({ failed: 0, unavailable: 0, total: 3 }), 0);
  assert.equal(exitCode({ failed: 0, unavailable: 0, total: 0 }), 0, "no case selected is not an outage");
});

test("the declared markers separate the two answers, not merely mention the subject", async () => {
  // The trap this nearly shipped with: an English answer recommending the Lua callback can say
  // "in mission.yaml" and "these settings" in prose, so those words alone pass on the very answer
  // the case exists to catch. The YAML keys, colon included, are what only the simple path writes.
  const wrong =
    "Since the CSAR module is enabled in mission.yaml, keep the callback to apply these settings: " +
    "csar.csarOncrash = false, csar.enableForAI = false.";
  const right = [
    "Drop the Lua block and put this in your mission.yaml:",
    "```yaml",
    "modules:",
    "  CSAR:",
    "    settings:",
    "      csarOncrash: false",
    "```",
  ].join("\n");
  const { cases } = JSON.parse(await readFile(new URL("../scripts/answer-cases.json", import.meta.url), "utf8"));
  for (const id of ["csar-booleans-fr", "csar-booleans-en"]) {
    const spec = cases.find((c) => c.id === id);
    assert.equal(verdict(wrong, spec).ok, false, `${id} must reject the callback answer`);
    assert.equal(verdict(right, spec).ok, true, `${id} must accept the YAML answer`);
  }
});
