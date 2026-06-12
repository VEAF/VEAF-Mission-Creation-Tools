import { test } from "node:test";
import assert from "node:assert/strict";
import { chunkMarkdown, MAX_CHARS } from "../scripts/build-index.mjs";
import { latestQuery, toGeminiContents, upstreamErrorMessage, isAllowedClient } from "../src/index.js";

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
