/**
 * Replay the questions that a wrong answer once shipped on, against the **live** assistant.
 *
 * What this checks is not a function, it is a model's answer, and no unit test reaches it: the
 * system instruction is a string a test can pin, but a string being present says nothing about
 * what the model does with it. That gap is the whole subject of `FIX-SUPPORT-ASK-ANSWERS-THE-NEED`
 * — the assistant's answers were *correct* and still failed the asker, which is precisely the class
 * of defect an assertion on the instruction cannot see.
 *
 * So the cases live in `answer-cases.json` as questions and markers, and this replays them through
 * the deployed Worker exactly as a caller does. It needs no secret: the `cli` client mode is
 * declarable by header, which is also what makes this runnable by hand after a deploy.
 *
 * Usage (from poc/doc-chatbot/worker):
 *
 *     node scripts/replay-answers.mjs
 *     node scripts/replay-answers.mjs --endpoint https://veaf-docs-chatbot.veaf.workers.dev/chat
 *     node scripts/replay-answers.mjs --case csar-aircrafttype-fr
 *
 * Three exit codes, because "no case failed" and "no case was asked" must not look alike. A check
 * that goes green having measured nothing is the failure this repository has already paid for
 * twice — the index frozen for six weeks behind a command that printed `Success!`, and the two dead
 * in-game checks that could not fail either way:
 *
 *   - **0** — at least one case was asked, and none failed.
 *   - **1** — a case was asked and its answer did not satisfy it.
 *   - **2** — nothing could be asked at all. Not the assistant being wrong: either the free Gemini
 *     allowance is spent for the day (shared with every visitor of the documentation site and with
 *     the Discord bot, and reported in the Worker's error payload), or the per-minute rate limit
 *     was hit, which is why the cases are paced.
 *
 * A model is not deterministic, so a single green run is evidence, not proof. Read a red case as
 * "go and look", not as a build to revert on sight — which is also why nothing gates on this.
 */

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

/** The deployed assistant. Overridable so a preview deployment can be checked before it ships. */
export const DEFAULT_ENDPOINT = "https://veaf-docs-chatbot.veaf.workers.dev/chat";

/**
 * Seconds between two cases.
 *
 * The `cli` client is allowed 10 requests per 60 seconds, and a 429 arrives as an HTTP status with
 * no answer at all — indistinguishable, in a log, from a case that produced nothing. Pacing costs a
 * few seconds and removes the ambiguity.
 */
export const PACING_SECONDS = 8;

/**
 * A descriptive User-Agent, and not an optional politeness.
 *
 * Cloudflare's managed rules answer **403 with body `error code: 1010`** to a request carrying no
 * User-Agent — before the Worker runs, so nothing in the Worker's own logs shows it. Measured
 * 2026-09-22 from Node's default client, which sends none: every call was refused, and the refusal
 * reads exactly like the client-admission 403 the Worker itself returns.
 */
const USER_AGENT = "veaf-docs-chatbot-replay";

/**
 * Decide whether one answer satisfies its case.
 *
 * Markers are matched case-insensitively on the raw answer text, which is what a reader sees.
 * Three lists, because the two directions of the defect need different shapes:
 *
 *   - `expectAll` — every marker must appear. Used for the simple path: naming `mission.yaml` while
 *     never showing the setting would pass a looser check and help nobody.
 *   - `expectAny` — at least one. Used where several wordings are equally right.
 *   - `forbid` — none may appear. This is the guardrail: the fix must not trade one wrong default
 *     for the other, and a YAML block for a setting YAML cannot carry does not merely read badly,
 *     it does not work.
 *
 * @param {string} answer The assistant's answer, as text.
 * @param {{expectAll?: string[], expectAny?: string[], forbid?: string[]}} spec The case.
 * @returns {{ok: boolean, missing: string[], forbidden: string[], noneOf: string[]}} The verdict,
 *   naming what was missing rather than only that something was.
 */
export function verdict(answer, spec) {
  const haystack = (answer || "").toLowerCase();
  const has = (marker) => haystack.includes(marker.toLowerCase());
  const missing = (spec.expectAll ?? []).filter((marker) => !has(marker));
  const forbidden = (spec.forbid ?? []).filter(has);
  const any = spec.expectAny ?? [];
  // An empty `expectAny` is "nothing required", not "nothing satisfies it": `[].some()` is false,
  // which would fail every case that only uses `expectAll`.
  const noneOf = any.length && !any.some(has) ? any : [];
  return { ok: !missing.length && !forbidden.length && !noneOf.length, missing, forbidden, noneOf };
}

/**
 * Turn the Worker's SSE body into the answer text.
 *
 * @param {string} body The whole `text/event-stream` response.
 * @returns {{text: string, error: string|null}} The concatenated fragments, and the Worker's own
 *   error message when it sent one. An error inside a 200 stream is how generation failures arrive,
 *   so a caller that only reads the status reports an empty answer for a quota refusal.
 */
export function parseStream(body) {
  const out = [];
  let error = null;
  for (const line of body.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("data:")) continue;
    const payload = trimmed.slice(5).trim();
    if (!payload || payload === "[DONE]") continue;
    let data;
    try {
      data = JSON.parse(payload);
    } catch {
      continue;
    }
    if (!data || typeof data !== "object") continue;
    if (data.error) error = String(data.error);
    if (typeof data.text === "string") out.push(data.text);
  }
  return { text: out.join(""), error };
}

/**
 * Build the conversation sent for one case.
 *
 * The question is the **last** user turn and carries nothing else: the Worker embeds that turn
 * verbatim to retrieve passages, so an instruction appended to it would be embedded with it and
 * retrieval would degrade. This mirrors what the support bot does with its sources protocol.
 *
 * @param {string} question The question, verbatim.
 * @returns {{role: string, content: string}[]} The turns, oldest first.
 */
export function conversation(question) {
  return [{ role: "user", content: question }];
}

/**
 * Ask the live assistant one question.
 *
 * @param {string} endpoint The Worker `/chat` URL.
 * @param {{question: string, lang: string}} spec The case.
 * @param {typeof fetch} [fetchImpl] Injected by the tests.
 * @returns {Promise<{text: string, error: string|null, status: number}>} What came back.
 */
export async function askLive(endpoint, spec, fetchImpl = fetch) {
  const response = await fetchImpl(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-VEAF-Client": "cli",
      "User-Agent": USER_AGENT,
    },
    // No `subject`: the Worker only honours one for a client mode holding a secret, and `cli` holds
    // none, so its rate limit is keyed on the caller's IP whatever is sent. Sending one anyway
    // would read as a quota this script controls, which it does not.
    body: JSON.stringify({ lang: spec.lang, messages: conversation(spec.question) }),
  });
  const body = await response.text();
  if (!response.ok) {
    return { text: "", error: `HTTP ${response.status}: ${body.slice(0, 200)}`, status: response.status };
  }
  return { ...parseStream(body), status: response.status };
}

/**
 * Turn a run's tally into the process exit code.
 *
 * Its own function so the rule below is a testable claim rather than three lines inside `main`,
 * which needs a deployed Worker to reach.
 *
 * @param {{failed: number, unavailable: number, total: number}} tally What the run produced.
 * @returns {0|1|2} 1 when a case failed, 2 when nothing could be asked, 0 otherwise.
 */
export function exitCode({ failed, unavailable, total }) {
  if (failed) return 1;
  // A run where every case was unavailable measured nothing, and must not exit the way a green run
  // does: that is how a check ends up certifying a fix that was never observed.
  if (total && unavailable === total) return 2;
  return 0;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function arg(argv, name, fallback = null) {
  const i = argv.indexOf(name);
  if (i === -1) return fallback;
  const value = argv[i + 1];
  if (!value || value.startsWith("--")) throw new Error(`${name} needs a value`);
  return value;
}

async function main(argv) {
  const endpoint = arg(argv, "--endpoint", DEFAULT_ENDPOINT);
  const only = arg(argv, "--case", null);
  const file = path.join(path.dirname(fileURLToPath(import.meta.url)), "answer-cases.json");
  const { cases } = JSON.parse(await readFile(file, "utf8"));
  const selected = only ? cases.filter((c) => c.id === only) : cases;
  if (!selected.length) throw new Error(`no case matches ${JSON.stringify(only)}`);

  console.log(`Replaying ${selected.length} case(s) against ${endpoint}\n`);
  let failed = 0;
  let unavailable = 0;
  for (const [index, spec] of selected.entries()) {
    if (index) await sleep(PACING_SECONDS * 1000);
    const { text, error } = await askLive(endpoint, spec);
    // An empty stream carrying no error is the same thing as an error for this purpose: the
    // assistant did not answer. Sent to `verdict` it would miss every marker and be printed as a
    // wrong answer, which is the one reading that is certainly false. The support bot draws the
    // same line, and calls it `FailureKind.EMPTY`.
    if (error || !text.trim()) {
      // Not a red case: the assistant never got to answer. Counted apart so a quota day cannot be
      // read as the fix having regressed.
      unavailable += 1;
      console.log(`⚠ ${spec.id}: no answer — ${error ?? "the stream carried no text"}`);
      continue;
    }
    const outcome = verdict(text, spec);
    if (outcome.ok) {
      console.log(`✓ ${spec.id}`);
      continue;
    }
    failed += 1;
    console.log(`✗ ${spec.id} — ${spec.why}`);
    if (outcome.missing.length) console.log(`    missing: ${outcome.missing.join(", ")}`);
    if (outcome.noneOf.length) console.log(`    none of: ${outcome.noneOf.join(", ")}`);
    if (outcome.forbidden.length) console.log(`    forbidden, and present: ${outcome.forbidden.join(", ")}`);
    console.log(`    answer:\n${text.replace(/^/gm, "      ")}`);
  }

  const code = exitCode({ failed, unavailable, total: selected.length });
  console.log("");
  if (unavailable) console.log(`${unavailable} case(s) could not be asked — see above.`);
  if (code === 1) console.log(`${failed} case(s) failed.`);
  // "Nothing failed" and "nothing was measured" are not the same sentence, and the second must not
  // be printed as the first: on a spent-allowance day every case is unavailable.
  else if (code === 2) console.log("No case could be asked, so nothing was measured.");
  else console.log(`All asked cases passed (${selected.length - unavailable} of ${selected.length}).`);
  return code;
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
