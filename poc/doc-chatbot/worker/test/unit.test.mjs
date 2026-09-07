import { test } from "node:test";
import assert from "node:assert/strict";
import { chunkMarkdown, MAX_CHARS } from "../scripts/build-index.mjs";
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
