/**
 * Build the Vectorize index for the VEAF documentation chatbot (POC).
 *
 * Reads the local Markdown docs (../../../../doc), splits them into chunks, embeds each chunk
 * with the Gemini embeddings API (gemini-embedding-001, 768 dims), and writes an NDJSON file
 * ready for `wrangler vectorize insert`.
 *
 * Usage (from poc/doc-chatbot/worker):
 *   GEMINI_API_KEY=... node scripts/build-index.mjs
 *   # then:
 *   npx wrangler vectorize insert veaf-docs --file vectors.ndjson
 *
 * The key is read from GEMINI_API_KEY, falling back to the .dev.vars file.
 */
import { readFile, writeFile, readdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const EMBED_MODEL = "gemini-embedding-001";
const EMBED_DIMS = 768;
const BASE = "https://generativelanguage.googleapis.com/v1beta/models";
const MAX_CHARS = 2000; // ~500 tokens/chunk: small heading-sections are merged up to this size
const BATCH = 50; // embeddings per batch — kept under the 100/min free-tier limit for headroom

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DOC_DIR = path.resolve(__dirname, "../../../../doc");
const WORKER_DIR = path.resolve(__dirname, "..");

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
        // slice it at the character level to guarantee no chunk blows the Vectorize metadata cap.
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
    const m = body.match(/retry in ([\d.]+)s/i) || body.match(/"retryDelay":\s*"(\d+)s"/);
    const wait = (m ? Math.ceil(parseFloat(m[1])) : 60) + 3;
    if (wait > 120) {
      throw new Error(`Daily embeddings quota likely exhausted (API asks to retry in ${wait}s). Try again later.`);
    }
    console.log(`  quota window hit, waiting ${wait}s then retrying…`);
    await sleep(wait * 1000);
    return embedBatch(key, texts, attempt + 1);
  }
  if (!res.ok) throw new Error(`batchEmbedContents ${res.status}: ${await res.text()}`);
  const json = await res.json();
  return json.embeddings.map((e) => e.values);
}

async function main() {
  const key = await resolveKey();
  const files = await collectMarkdown(DOC_DIR);
  console.log(`Found ${files.length} markdown files under ${DOC_DIR}`);

  // Build the chunk records before embedding.
  const records = [];
  for (const file of files) {
    const content = await readFile(file, "utf8");
    const relPath = path.relative(path.resolve(__dirname, "../../../../"), file).replace(/\\/g, "/");
    const lang = relPath.endsWith(".en.md") ? "en" : "fr";
    const title = titleOf(content, relPath);
    for (const text of chunkMarkdown(content)) {
      records.push({ text, lang, title, path: relPath });
    }
  }
  console.log(`Prepared ${records.length} chunks; embedding in batches of ${BATCH}…`);

  for (let i = 0; i < records.length; i += BATCH) {
    const batch = records.slice(i, i + BATCH);
    const vectors = await embedBatch(key, batch.map((r) => r.text));
    batch.forEach((r, j) => {
      r.vector = vectors[j];
    });
    console.log(`  embedded ${Math.min(i + BATCH, records.length)}/${records.length}`);
    // Free-tier embeddings allow 100 requests/min and each chunk counts as one request, so wait
    // out the per-minute window between batches.
    if (i + BATCH < records.length) {
      console.log("  waiting 61s for the embeddings free-tier quota window…");
      await sleep(61000);
    }
  }

  // Emit, per language: a binary Float32 blob of L2-normalized vectors (for in-Worker cosine) and
  // a bulk file of per-chunk texts keyed `idx:txt:{lang}:{i}` (matching the blob order) for KV.
  for (const lang of [...new Set(records.map((r) => r.lang))]) {
    const recs = records.filter((r) => r.lang === lang);
    const blob = new Float32Array(recs.length * EMBED_DIMS);
    recs.forEach((r, i) => blob.set(l2normalize(Float32Array.from(r.vector)), i * EMBED_DIMS));
    await writeFile(path.join(WORKER_DIR, `vec-${lang}.bin`), Buffer.from(blob.buffer));
    const bulk = recs.map((r, i) => ({
      key: `idx:txt:${lang}:${i}`,
      value: JSON.stringify({ text: r.text, title: r.title, path: r.path }),
    }));
    await writeFile(path.join(WORKER_DIR, `txt-${lang}.json`), JSON.stringify(bulk));
    console.log(`  ${lang}: ${recs.length} vectors -> vec-${lang}.bin, txt-${lang}.json`);
  }
  console.log("\nNext — upload the index to KV (see wrangler.toml header), e.g.:");
  console.log('  npx wrangler kv key  put --binding CHAT_KV "idx:vec:fr" --path vec-fr.bin');
  console.log("  npx wrangler kv bulk put --binding CHAT_KV txt-fr.json");
}

// Run only when executed directly (not when imported by tests).
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}

export { chunkMarkdown, MAX_CHARS };
