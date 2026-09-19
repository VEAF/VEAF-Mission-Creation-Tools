/**
 * Measure where to put the retrieval similarity floor (`MIN_SIMILARITY`).
 *
 * `DEFAULT_MIN_SIMILARITY = 0.35` shipped with #966 as an explicit guess — a guard against the
 * plainly unrelated, not a measured value. The measurement was deferred because it needs the Gemini
 * key; it also, unsaid, needed a *current* index, which only became true with #968.
 *
 * The method: ask questions the documentation answers and questions it does not, record the **top**
 * cosine of each against the live index, and look at where the two clouds sit.
 *
 * Three details decide whether this measures the same quantity the Worker compares against the
 * floor, and each would quietly give a different number:
 *
 *   - the question is embedded with task type `RETRIEVAL_QUERY`; the index chunks were embedded
 *     with `RETRIEVAL_DOCUMENT` (see build-index.mjs). Mixing them measures something else.
 *   - same model, same `outputDimensionality`.
 *   - the vectors compared against are the ones **fetched from KV**, not a fresh local build. What
 *     is served and what the repository would build are not guaranteed equal — that was the whole
 *     subject of the previous lot.
 *
 * Usage (from poc/doc-chatbot/worker), after fetching the index:
 *
 *     npx wrangler kv key get --remote --binding CHAT_KV --preview false "idx:vec:fr" > vec-fr.bin
 *     GEMINI_API_KEY=... node scripts/calibrate-floor.mjs --lang fr --vectors vec-fr.bin
 *
 * Prints one line per question and a summary of the two clouds. It chooses nothing: picking the
 * value is a judgement about which mistake costs more, and that belongs in the PRD.
 */

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const EMBED_MODEL = "gemini-embedding-001";
const EMBED_DIMS = 768;
const BASE = "https://generativelanguage.googleapis.com/v1beta/models";

/** Task type the Worker uses for the *question* side. Not the one the index used. */
const QUERY_TASK_TYPE = "RETRIEVAL_QUERY";

/**
 * Scale a vector to unit length, as both the index and the Worker do before comparing.
 *
 * @param {Float32Array|number[]} v The raw embedding.
 * @returns {Float32Array} The same direction, length 1 (or unchanged when the norm is 0).
 */
export function l2normalize(v) {
  let sum = 0;
  for (const x of v) sum += x * x;
  const norm = Math.sqrt(sum);
  const out = Float32Array.from(v);
  if (norm > 0) for (let i = 0; i < out.length; i++) out[i] /= norm;
  return out;
}

/**
 * The best cosine between a query and any chunk of the index.
 *
 * The index blob is a flat run of L2-normalised `dims`-wide vectors, so the cosine is a plain dot
 * product — exactly the loop `retrieveContext` runs in the Worker.
 *
 * @param {Float32Array} query The normalised query embedding.
 * @param {Float32Array} vectors The whole index blob.
 * @param {number} dims Vector width.
 * @returns {number} The highest score, or -1 when the index is empty.
 * @throws {Error} When the blob is not a whole number of vectors, which means a truncated download.
 */
export function topScore(query, vectors, dims = EMBED_DIMS) {
  if (vectors.length % dims !== 0) {
    throw new Error(`the index blob holds ${vectors.length} floats, not a multiple of ${dims}`);
  }
  const count = vectors.length / dims;
  let best = -1;
  for (let i = 0; i < count; i++) {
    const off = i * dims;
    let dot = 0;
    for (let d = 0; d < dims; d++) dot += query[d] * vectors[off + d];
    if (dot > best) best = dot;
  }
  return best;
}

/**
 * Describe a set of scores: the range, and the quartile that matters for a floor.
 *
 * @param {number[]} scores Top scores, one per question.
 * @returns {{n: number, min: number, max: number, median: number}} Rounded to three decimals.
 */
export function summarise(scores) {
  if (!scores.length) return { n: 0, min: NaN, max: NaN, median: NaN };
  const sorted = [...scores].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  const median = sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  const round = (x) => Math.round(x * 1000) / 1000;
  return { n: sorted.length, min: round(sorted[0]), max: round(sorted.at(-1)), median: round(median) };
}

/**
 * Say whether a floor can separate the two sets, and where the overlap is if it cannot.
 *
 * Deliberately returns the *facts*, not a recommendation: which mistake costs more is a judgement
 * (a floor too high gags the assistant on documented questions and looks like missing
 * documentation; too low is a no-op, since the model still judges the excerpts).
 *
 * @param {number[]} documented Top scores for questions the documentation answers.
 * @param {number[]} undocumented Top scores for questions it does not.
 * @returns {{separable: boolean, gapLow: number, gapHigh: number, overlap: number}}
 */
export function separation(documented, undocumented) {
  const gapLow = Math.max(...undocumented);
  const gapHigh = Math.min(...documented);
  const overlap = documented.filter((s) => s <= gapLow).length + undocumented.filter((s) => s >= gapHigh).length;
  return { separable: gapHigh > gapLow, gapLow, gapHigh, overlap };
}

async function embedQuery(key, text) {
  const res = await fetch(`${BASE}/${EMBED_MODEL}:embedContent?key=${key}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: `models/${EMBED_MODEL}`,
      content: { parts: [{ text }] },
      taskType: QUERY_TASK_TYPE,
      outputDimensionality: EMBED_DIMS,
    }),
  });
  if (!res.ok) throw new Error(`embed ${res.status}: ${(await res.text().catch(() => "")).slice(0, 300)}`);
  return (await res.json()).embedding.values;
}

function arg(argv, name, fallback = null) {
  const i = argv.indexOf(name);
  if (i === -1) return fallback;
  const value = argv[i + 1];
  if (!value || value.startsWith("--")) throw new Error(`${name} needs a value`);
  return value;
}

async function main(argv) {
  const lang = arg(argv, "--lang", "fr");
  const vectorsFile = arg(argv, "--vectors", `vec-${lang}.bin`);
  const questionsFile = arg(argv, "--questions", path.join(path.dirname(fileURLToPath(import.meta.url)), "calibration-questions.json"));
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error("GEMINI_API_KEY is not set");

  const buf = await readFile(vectorsFile);
  const vectors = new Float32Array(buf.buffer, buf.byteOffset, buf.byteLength / 4);
  const all = JSON.parse(await readFile(questionsFile, "utf8"));
  const questions = all[lang];
  if (!questions) throw new Error(`no questions for language ${JSON.stringify(lang)}`);

  console.log(`${lang}: ${vectors.length / EMBED_DIMS} indexed chunks from ${vectorsFile}\n`);
  const scores = { documented: [], undocumented: [] };
  for (const group of ["documented", "undocumented"]) {
    console.log(`— ${group} —`);
    for (const question of questions[group]) {
      const score = topScore(l2normalize(await embedQuery(key, question)), vectors);
      scores[group].push(score);
      console.log(`  ${score.toFixed(3)}  ${question}`);
    }
    console.log("");
  }

  for (const group of ["documented", "undocumented"]) {
    const { n, min, max, median } = summarise(scores[group]);
    console.log(`${group.padEnd(13)} n=${n}  min=${min}  median=${median}  max=${max}`);
  }
  const { separable, gapLow, gapHigh, overlap } = separation(scores.documented, scores.undocumented);
  console.log("");
  if (separable) {
    console.log(`The clouds separate: nothing undocumented scores above ${gapLow.toFixed(3)}, nothing`);
    console.log(`documented below ${gapHigh.toFixed(3)}. Any floor in between separates them.`);
  } else {
    console.log(`The clouds OVERLAP by ${overlap} question(s): undocumented reach ${gapLow.toFixed(3)}`);
    console.log(`while documented go down to ${gapHigh.toFixed(3)}. No floor separates them cleanly —`);
    console.log(`prefer the low side, since gagging a documented question is the worse mistake.`);
  }
  return 0;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  main(process.argv.slice(2)).then(
    (code) => process.exit(code),
    (error) => {
      console.error(error.message);
      process.exit(1);
    },
  );
}
