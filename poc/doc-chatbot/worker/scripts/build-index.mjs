/**
 * Build the documentation chatbot embeddings index (KV format) for the VEAF docs.
 *
 * Reads the local Markdown docs (../../../../doc), splits them into chunks, embeds each chunk with
 * the Gemini embeddings API (gemini-embedding-001, 768 dims) and writes, per language, ONE KV value
 * each:
 *   - vec-{lang}.bin   : a binary Float32 blob of L2-normalized vectors (in-Worker cosine search)
 *   - txt-{lang}.json  : a JSON array of {text, title, path}, in the same order as the blob
 *
 * TWO free-tier quotas of 1000/day sit on this pipeline, and for a long time this header named only
 * the guarded one:
 *
 *   - Gemini embeddings, 1000 requests/day. GUARDED by a content-addressed cache
 *     (.embed-cache.json, keyed by the SHA-256 of the chunk text) reused across runs, so only
 *     new/changed chunks are embedded. In CI it is persisted with actions/cache, and a typical doc
 *     edit costs a handful of embeds. With no cache (cold run) every chunk is embedded.
 *   - Cloudflare KV writes, 1000/day ACCOUNT-WIDE. Guarded by the layout above: one value per
 *     language instead of one per chunk, so a reindex costs FOUR writes whatever changed. It used
 *     to cost one write per chunk — measured 2026-09-21 at 1397, so a single full reindex already
 *     exceeded the daily cap and every run after the first one of the day failed before writing a
 *     byte. Note that the Worker also spends two KV writes per chat request on its rate-limit
 *     counters, out of the same account-wide 1000.
 *
 * Adding a per-chunk KV key would put the second quota back where it was. The write cost is printed
 * at the end of a run, and the workflow puts it in the job summary, so a regression is visible.
 *
 * Usage (from poc/doc-chatbot/worker):
 *   GEMINI_API_KEY=... node scripts/build-index.mjs
 *   then upload the four outputs to KV (see wrangler.toml header).
 *
 * The key is read from GEMINI_API_KEY, falling back to the .dev.vars file.
 */
import { readFile, writeFile, readdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import path from "node:path";

const EMBED_MODEL = "gemini-embedding-001";
const EMBED_DIMS = 768;
const BASE = "https://generativelanguage.googleapis.com/v1beta/models";
const MAX_CHARS = 2000; // ~500 tokens/chunk: small heading-sections are merged up to this size
const BATCH = 50; // embeddings per batch — kept under the 100/min free-tier limit for headroom

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DOC_DIR = path.resolve(__dirname, "../../../../doc");
const WORKER_DIR = path.resolve(__dirname, "..");
const CACHE_FILE = path.join(WORKER_DIR, ".embed-cache.json");

const sha256 = (text) => createHash("sha256").update(text).digest("hex");

/** In-place L2 normalization so the Worker's cosine similarity reduces to a dot product. */
function l2normalize(v) {
  let sumSq = 0;
  for (let i = 0; i < v.length; i++) sumSq += v[i] * v[i];
  const norm = Math.sqrt(sumSq) || 1;
  for (let i = 0; i < v.length; i++) v[i] /= norm;
  return v;
}

async function resolveKey() {
  if (process.env.GEMINI_API_KEY) return process.env.GEMINI_API_KEY;
  try {
    const devVars = await readFile(path.resolve(__dirname, "../.dev.vars"), "utf8");
    const match = devVars.match(/^GEMINI_API_KEY=(.+)$/m);
    if (match) return match[1].trim();
  } catch {
    /* no .dev.vars */
  }
  throw new Error("GEMINI_API_KEY not set (env var or .dev.vars)");
}

/** Recursively collect every Markdown file under a directory. */
async function collectMarkdown(dir) {
  const out = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...(await collectMarkdown(full)));
    else if (entry.name.endsWith(".md")) out.push(full);
  }
  return out;
}

/**
 * Split markdown into chunks: greedily merge consecutive heading-sections up to MAX_CHARS (so we
 * don't end up with hundreds of tiny one-heading chunks), and hard-split any oversized section.
 */
function chunkMarkdown(content) {
  const chunks = [];
  let buf = "";
  const flush = () => {
    if (buf.trim()) chunks.push(buf.trim());
    buf = "";
  };
  for (const section of content.split(/\n(?=#{1,6}\s)/)) {
    const sec = section.trim();
    if (!sec) continue;
    if (sec.length > MAX_CHARS) {
      flush();
      let b = "";
      for (const para of sec.split(/\n\s*\n/)) {
        // A single paragraph (e.g. a big table or code block) can itself exceed MAX_CHARS, so
        // slice it at the character level to guarantee no chunk blows the metadata size cap.
        for (let k = 0; k < para.length; k += MAX_CHARS) {
          const piece = para.slice(k, k + MAX_CHARS);
          if (b && b.length + piece.length + 2 > MAX_CHARS) {
            chunks.push(b.trim());
            b = piece;
          } else {
            b = b ? `${b}\n\n${piece}` : piece;
          }
        }
      }
      if (b.trim()) chunks.push(b.trim());
    } else {
      if (buf && buf.length + sec.length + 2 > MAX_CHARS) flush();
      buf = buf ? `${buf}\n\n${sec}` : sec;
    }
  }
  flush();
  return chunks;
}

function titleOf(content, relPath) {
  const m = content.match(/^#\s+(.+)$/m);
  return m ? m[1].trim() : path.basename(relPath);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Load the content-addressed embedding cache ({sha256: number[]}); empty on a cold run. */
async function loadCache() {
  try {
    return JSON.parse(await readFile(CACHE_FILE, "utf8"));
  } catch {
    return {};
  }
}

async function embedBatch(key, texts, attempt = 0) {
  const res = await fetch(`${BASE}/${EMBED_MODEL}:batchEmbedContents?key=${key}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      requests: texts.map((t) => ({
        model: `models/${EMBED_MODEL}`,
        content: { parts: [{ text: t }] },
        taskType: "RETRIEVAL_DOCUMENT",
        outputDimensionality: EMBED_DIMS,
      })),
    }),
  });
  if (res.status === 429 && attempt < 6) {
    const body = await res.text();
    // A per-DAY quota cannot clear by retrying within the run — fail fast with a clear message
    // (the API sometimes still returns a short retryDelay for it, so detect the quota id/text).
    if (/per[\s_]?day|RequestsPerDay/i.test(body)) {
      throw new Error(
        "Daily embeddings free-tier quota (1000/day for gemini-embedding-001) is exhausted. " +
          "Re-run after it resets (midnight Pacific).",
      );
    }
    const m = body.match(/retry in ([\d.]+)s/i) || body.match(/"retryDelay":\s*"(\d+)s"/);
    const wait = (m ? Math.ceil(parseFloat(m[1])) : 60) + 3;
    if (wait > 120) {
      throw new Error(`Embeddings quota retry delay too long (${wait}s) — aborting; try again later.`);
    }
    console.log(`  quota window hit, waiting ${wait}s then retrying…`);
    await sleep(wait * 1000);
    return embedBatch(key, texts, attempt + 1);
  }
  if (!res.ok) throw new Error(`batchEmbedContents ${res.status}: ${await res.text()}`);
  const json = await res.json();
  return json.embeddings.map((e) => e.values);
}

/**
 * How many KV keys one language's index occupies: `idx:vec:{lang}` and `idx:txt:{lang}`.
 *
 * This is the number the daily write quota is spent on, and it must not depend on how many chunks
 * the documentation produces. It is exported so a test can pin it.
 */
export const KV_KEYS_PER_LANGUAGE = 2;

/** Where the run records its upload cost in KV writes, for the workflow's job summary. */
export const KV_WRITE_COST_FILE = "kv-write-cost.txt";

/**
 * Build the two KV values a language needs, from its chunk records and the embedding cache.
 *
 * The pair is POSITIONAL: entry `i` of the text array describes vector `i` of the blob. That is
 * what keeps the index at two keys per language instead of one per chunk — and it is why the
 * Worker has to refuse a pair whose halves disagree on length, which would otherwise hand out the
 * wrong passage for a vector without any error.
 *
 * The cache is keyed on the chunk text alone — not on the model or its dimensionality — so a
 * vector of the wrong width is reachable: change `EMBED_MODEL` or `EMBED_DIMS`, or carry a cache
 * written by an older build, and the stale entries come back a different size. Measured
 * 2026-09-21 with a 384-wide entry among 768-wide ones: `blob.set` writes what it is given and
 * leaves the rest of the slot at zero, so the blob length and the passage count both stay exactly
 * right and the Worker's length check passes. That passage then ranks on a half-zeroed vector, and
 * nothing anywhere says so. A wider entry is no better — it spills into the next chunk's slot, or
 * throws an opaque RangeError when the spill happens to be the last one. Hence the explicit width
 * check: the length check in the Worker closes skew by insertion, this closes skew by dimension.
 *
 * @param {{text: string, title: string, path: string, hash: string}[]} recs The language's chunks,
 *   in the order they are to be indexed.
 * @param {Record<string, number[]>} cache Embedding vectors by chunk hash.
 * @returns {{vec: Buffer, txt: string}} The `idx:vec:{lang}` and `idx:txt:{lang}` values.
 * @throws {Error} When a chunk has no cached vector, or one of the wrong dimensionality.
 */
export function buildLanguageValues(recs, cache) {
  const blob = new Float32Array(recs.length * EMBED_DIMS);
  recs.forEach((r, i) => {
    const vector = cache[r.hash];
    // Named rather than left to `Float32Array.from(undefined)`, which says "undefined is not
    // iterable" after a full embedding run and points at nothing.
    if (!vector) throw new Error(`no embedding cached for ${r.path} (chunk hash ${r.hash})`);
    if (vector.length !== EMBED_DIMS) {
      throw new Error(
        `cached embedding for ${r.path} is ${vector.length} wide, expected ${EMBED_DIMS} — ` +
          `delete .embed-cache.json and rebuild (the cache is keyed on text, not on the model)`,
      );
    }
    blob.set(l2normalize(Float32Array.from(vector)), i * EMBED_DIMS);
  });
  const texts = recs.map((r) => ({ text: r.text, title: r.title, path: r.path }));
  return { vec: Buffer.from(blob.buffer), txt: JSON.stringify(texts) };
}

async function main() {
  const files = await collectMarkdown(DOC_DIR);
  console.log(`Found ${files.length} markdown files under ${DOC_DIR}`);

  // Build the chunk records (with a content hash) before embedding.
  const records = [];
  for (const file of files) {
    const content = await readFile(file, "utf8");
    const relPath = path.relative(path.resolve(__dirname, "../../../../"), file).replace(/\\/g, "/");
    const lang = relPath.endsWith(".en.md") ? "en" : "fr";
    const title = titleOf(content, relPath);
    for (const text of chunkMarkdown(content)) {
      records.push({ text, lang, title, path: relPath, hash: sha256(text) });
    }
  }

  // Incremental: reuse cached vectors; only embed chunks whose text is new/changed.
  const cache = await loadCache();
  const toEmbed = records.filter((r) => !cache[r.hash]);
  console.log(
    `Prepared ${records.length} chunks; ${records.length - toEmbed.length} cached, ${toEmbed.length} to embed.`,
  );

  if (toEmbed.length) {
    const key = await resolveKey();
    for (let i = 0; i < toEmbed.length; i += BATCH) {
      const batch = toEmbed.slice(i, i + BATCH);
      const vectors = await embedBatch(key, batch.map((r) => r.text));
      batch.forEach((r, j) => {
        cache[r.hash] = vectors[j];
      });
      console.log(`  embedded ${Math.min(i + BATCH, toEmbed.length)}/${toEmbed.length}`);
      // Free-tier embeddings allow 100 requests/min and each chunk counts as one request, so wait
      // out the per-minute window between batches.
      if (i + BATCH < toEmbed.length) {
        console.log("  waiting 61s for the embeddings free-tier quota window…");
        await sleep(61000);
      }
    }
  }

  // Persist the cache, pruned to the chunks that currently exist (bounds its size).
  const pruned = {};
  for (const r of records) pruned[r.hash] = cache[r.hash];
  await writeFile(CACHE_FILE, JSON.stringify(pruned));

  // Emit the two KV values per language (see buildLanguageValues).
  const langs = [...new Set(records.map((r) => r.lang))];
  for (const lang of langs) {
    const recs = records.filter((r) => r.lang === lang);
    const { vec, txt } = buildLanguageValues(recs, cache);
    await writeFile(path.join(WORKER_DIR, `vec-${lang}.bin`), vec);
    await writeFile(path.join(WORKER_DIR, `txt-${lang}.json`), txt);
    console.log(
      `  ${lang}: ${recs.length} chunks -> vec-${lang}.bin (${vec.length} B), ` +
        `txt-${lang}.json (${Buffer.byteLength(txt)} B)`,
    );
  }

  // The cost of the upload, in the unit that runs out. Printed here and picked up by the workflow
  // for the job summary: the previous layout cost one write per chunk and nothing ever said so.
  const writes = langs.length * KV_KEYS_PER_LANGUAGE;
  await writeFile(path.join(WORKER_DIR, KV_WRITE_COST_FILE), String(writes));
  console.log(
    `\nKV writes to upload this index: ${writes} ` +
      `(${KV_KEYS_PER_LANGUAGE} keys x ${langs.length} languages), out of 1000/day account-wide.`,
  );
  console.log("Next — upload the index to KV (see wrangler.toml header), e.g.:");
  console.log('  npx wrangler kv key put --remote --binding CHAT_KV --preview false "idx:vec:fr" --path vec-fr.bin');
  console.log('  npx wrangler kv key put --remote --binding CHAT_KV --preview false "idx:txt:fr" --path txt-fr.json');
}

// Run only when executed directly (not when imported by tests).
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}

export { chunkMarkdown, MAX_CHARS };
