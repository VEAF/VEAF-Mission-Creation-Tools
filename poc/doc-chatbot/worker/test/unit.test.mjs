import { test } from "node:test";
import assert from "node:assert/strict";
import { chunkMarkdown, MAX_CHARS } from "../scripts/build-index.mjs";
import {
  latestQuery,
  toGeminiContents,
  upstreamErrorMessage,
  isAllowedClient,
  resolveClient,
  allowRequest,
  declaredBodyTooLarge,
  readBoundedText,
  logAnalysisInstruction,
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

test("upstreamErrorMessage maps a Gemini 429 to the localized rate-limit message", () => {
  assert.equal(upstreamErrorMessage("fr", 429), "Trop de requêtes, réessayez dans un instant.");
  assert.equal(upstreamErrorMessage("en", 429), "Too many requests, please try again shortly.");
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

test("allowRequest refuses an undeclared client outright", async () => {
  assert.equal(await allowRequest(fakeKv(), "not-a-client", "1.2.3.4"), false);
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
