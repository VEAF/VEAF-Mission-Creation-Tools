/**
 * Prove that the embeddings index actually reached the KV namespace.
 *
 * Why this exists: `wrangler kv key put` and `wrangler kv bulk put` default to the **local**
 * Miniflare store. In CI that store is a directory inside the runner, deleted with it — so the
 * upload step embedded the whole documentation, wrote it to a temporary folder, printed `Success!`
 * and uploaded nothing. It reported success on every run from the wrangler 4 bump (2026-08-08)
 * until this was found on 2026-09-19, and the live assistant answered from an index frozen in
 * early August the whole time.
 *
 * `--remote` fixes the immediate bug. This script fixes the reason nobody noticed: a green run now
 * means the bytes are in the namespace, because they were read back out of it and compared.
 *
 * The index is four KV values — `idx:vec:{lang}` and `idx:txt:{lang}` for each language — and all
 * four are checked. `--vec` and `--txt` differ only in the label they print: both compare the whole
 * value byte for byte. `--txt` used to single out the last entry of a `wrangler kv bulk put` file,
 * because the texts were one KV entry per chunk; that layout cost 1397 writes a rebuild against a
 * cap of 1000 a day and is gone.
 *
 * Usage (from poc/doc-chatbot/worker, after the uploads):
 *
 *     node scripts/verify-index-upload.mjs \
 *       --vec fr vec-fr.bin remote-vec-fr.bin \
 *       --txt fr txt-fr.json remote-txt-fr.json
 *
 * Exits non-zero, naming every mismatch, when a read-back is missing, empty, or different from what
 * was built. A stale index left in place fails exactly like an empty one — which is the case that
 * actually happened.
 */

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

/**
 * What `wrangler kv key get` prints, **to stdout and exiting 0**, when the key is not there.
 *
 * Measured on 2026-09-19 against wrangler 4.120: a missing key is not an error as far as the shell
 * is concerned, so `set -e` does not catch it and a redirect produces a 16-byte file that looks like
 * a value. Without this, an absent key is reported as a size mismatch — true, but it sends the
 * reader looking for a stale index that is not there.
 */
export const KV_MISSING_SENTINEL = "Value not found";

/**
 * Compare what was uploaded with what came back out of the namespace.
 *
 * @param {string} label What is being checked, for the failure message.
 * @param {Buffer|Uint8Array|null} expected The bytes the build produced.
 * @param {Buffer|Uint8Array|null} actual The bytes read back from KV, or null when the read failed.
 * @returns {string|null} A problem description, or null when the two agree.
 */
export function compareBytes(label, expected, actual) {
  if (actual === null || actual === undefined) {
    return `${label}: nothing came back from the namespace — the upload did not happen`;
  }
  if (actual.length === 0) {
    return `${label}: the namespace returned 0 bytes — the upload did not happen`;
  }
  if (Buffer.from(actual).toString("utf8").trim() === KV_MISSING_SENTINEL) {
    return `${label}: the key is not in the namespace — this build's entries were never uploaded`;
  }
  if (actual.length !== expected.length) {
    return (
      `${label}: the namespace holds ${actual.length} bytes, the build produced ${expected.length} — ` +
      `an older index is still in place`
    );
  }
  if (!Buffer.from(expected).equals(Buffer.from(actual))) {
    return `${label}: same length but different bytes — the namespace does not hold this build`;
  }
  return null;
}

/** Human-readable name of what a check kind covers, for the failure message. */
const LABELS = { "--vec": "vectors", "--txt": "texts" };

/**
 * Parse the `--vec`/`--txt` triples off the command line.
 *
 * @param {string[]} argv The arguments after the script name.
 * @returns {{kind: string, lang: string, built: string, readBack: string}[]} One check per triple.
 * @throws {Error} On an unknown flag or a truncated triple.
 */
export function parseChecks(argv) {
  const checks = [];
  for (let i = 0; i < argv.length; ) {
    const kind = argv[i];
    if (kind !== "--vec" && kind !== "--txt") {
      throw new Error(`unknown argument ${JSON.stringify(kind)} — expected --vec or --txt`);
    }
    const values = argv.slice(i + 1, i + 4);
    // A triple cut short by the next flag would otherwise be read as a file named "--txt", and fail
    // later as "nothing came back" — a true statement about the wrong thing.
    const [lang, built, readBack] = values;
    if (values.length < 3 || values.some((v) => !v || v.startsWith("--"))) {
      throw new Error(`${kind} needs three values: <lang> <built-file> <read-back-file>`);
    }
    checks.push({ kind, lang, built, readBack });
    i += 4;
  }
  if (checks.length === 0) {
    throw new Error("no checks requested — pass at least one --vec or --txt triple");
  }
  return checks;
}

/** Read a file, returning null when it does not exist (a read-back that never happened). */
async function readOrNull(file) {
  try {
    return await readFile(file);
  } catch {
    return null;
  }
}

/**
 * Run every requested check and return the problems found.
 *
 * @param {{kind: string, lang: string, built: string, readBack: string}[]} checks From parseChecks.
 * @returns {Promise<string[]>} One line per problem; empty means the namespace holds this build.
 */
export async function runChecks(checks) {
  const problems = [];
  for (const { kind, lang, built, readBack } of checks) {
    const actual = await readOrNull(readBack);
    const expected = await readFile(built);
    const problem = compareBytes(`${LABELS[kind]} (${lang})`, expected, actual);
    if (problem) problems.push(problem);
  }
  return problems;
}

async function main(argv) {
  const problems = await runChecks(parseChecks(argv));
  if (problems.length) {
    console.error("The index is NOT in the namespace:");
    for (const problem of problems) console.error(`  - ${problem}`);
    return 1;
  }
  console.log("Index verified: the namespace holds exactly what this build produced.");
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
