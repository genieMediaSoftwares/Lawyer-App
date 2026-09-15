/**
 * Single entry point for Gemini generateContent calls.
 *
 * Previously each call site hardcoded its own model. `gemini-2.0-flash` was
 * the usual choice, and when that model's quota went to zero every OCR and
 * transcription call started failing silently while the main analysis (which
 * happened to have a fallback loop) kept working. The result was an intake
 * pipeline that produced confident output from documents it had never read.
 *
 * Every Gemini call now goes through generate(), so a model becoming
 * unavailable degrades uniformly and is logged in one place.
 */

/**
 * Models tried in order, and the reason each one is where it is.
 *
 * This list is not decorative: when every entry in it is dead, OCR,
 * transcription and extraction all fail at once and the intake reports a
 * generic failure to the client. That is exactly what happened to the previous
 * list — probed against this project's key on 2026-09-15, every one of its
 * four entries was gone:
 *
 *   gemini-2.5-flash       404 "no longer available to new users"
 *   gemini-2.0-flash       404 "no longer available"
 *   gemini-2.0-flash-lite  404 "no longer available"
 *   gemini-flash-latest    503, plain and structured alike
 *
 * ListModels still advertises several of those, so it is not a reliable guide
 * to what a key may actually call. Entries here are confirmed by a real
 * generateContent request carrying the extractor's own prompt and
 * responseSchema — never by the catalogue.
 *
 * Ordering is by measured latency, because on the full legal-extraction
 * payload (~10KB) the four working models returned the same answer: the right
 * city under the priority rules, the right court, and a 48-63 word summary.
 * When quality does not separate them, speed does.
 *
 *   gemini-3.5-flash-lite      2.3-2.6s   correct
 *   gemini-flash-lite-latest   2.1-2.5s   correct
 *   gemini-3.1-flash-lite      2.3-2.8s   correct
 *   gemini-3.5-flash          10-14s      correct, and timed out at 60s once
 *   gemini-flash-latest         503       both probe rounds
 *
 * So the lite models lead. `gemini-3.5-flash` is kept as the stronger reader
 * for a document the quick ones stumble on, but placed below them because its
 * long tail is paid on every request when it leads. The two `-latest` aliases
 * are what stop this list going stale silently again: Google repoints them, so
 * one of them should still answer after the pinned ids are retired.
 *
 * Deliberately excluded: `gemini-3.6-flash` and `gemini-3.7-flash`, both 503
 * on probing, and preview ids, which are withdrawn without notice.
 */
const DEFAULT_MODELS = [
  "gemini-3.5-flash-lite",
  "gemini-flash-lite-latest",
  "gemini-3.1-flash-lite",
  "gemini-3.5-flash",
  "gemini-flash-latest",
];

const ENDPOINT = (model) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

/**
 * Errors worth trying the next model for. A 400 (malformed request) will fail
 * identically on every model, so retrying it just wastes time and quota.
 */
const isModelLevelFailure = (status) =>
  status === 404 || status === 429 || status === 500 || status === 503;

class GeminiClient {
  get apiKey() {
    return process.env.GEMINI_API_KEY;
  }

  get isConfigured() {
    return Boolean(this.apiKey);
  }

  /**
   * Calls generateContent, walking the model list until one answers.
   *
   * @param {Array<object>} parts  Gemini `parts` array (text and/or inlineData).
   * @param {object}  [options]
   * @param {string[]} [options.models]      Override the model list.
   * @param {number}   [options.timeoutMs]   Per-attempt timeout. Default 60s —
   *   OCR over a multi-page scanned PDF genuinely takes tens of seconds.
   * @param {string}   [options.label]       Shown in logs to identify the caller.
   * @param {object}   [options.generationConfig] Passed straight through to the
   *   API. This is how a caller asks for native structured output
   *   (`responseMimeType: "application/json"` plus a `responseSchema`), which
   *   is far more reliable than asking for JSON in the prompt and parsing
   *   whatever prose comes back. Callers that use it should still be able to
   *   cope with a plain-text answer: a model that does not support the config
   *   answers 400, which `generate` reports as a fatal error rather than
   *   silently degrading.
   * @returns {Promise<{text: string|null, model: string|null, error: string|null}>}
   *   Never throws. Callers decide whether an empty result is fatal.
   */
  async generate(parts, options = {}) {
    const {
      models = DEFAULT_MODELS,
      timeoutMs = 60000,
      label = "gemini",
      passes = 2,
      passDelayMs = 2500,
      generationConfig = null,
    } = options;

    if (!this.isConfigured) {
      return { text: null, model: null, error: "GEMINI_API_KEY is not configured." };
    }

    let lastError = null;

    for (let pass = 0; pass < passes; pass++) {
      if (pass > 0) {
        console.warn(`[${label}] all models failed on pass ${pass}; retrying after ${passDelayMs}ms`);
        await new Promise((resolve) => setTimeout(resolve, passDelayMs));
      }

      const result = await this._attemptPass(parts, models, timeoutMs, label, generationConfig);
      if (result.text !== null) return result;

      // A non-retryable request-level error will fail identically next pass.
      if (result.fatal) return { text: null, model: null, error: result.error };

      lastError = result.error;
    }

    console.error(`[${label}] all Gemini models failed after ${passes} passes. Last error: ${lastError}`);
    return { text: null, model: null, error: lastError };
  }

  /** One walk through the model list. */
  async _attemptPass(parts, models, timeoutMs, label, generationConfig) {
    let lastError = null;
    // Counted so a stale DEFAULT_MODELS reports itself. When every model 404s
    // the run fails with whatever the last one said, which reads like a
    // transient outage; it is not, and no amount of retrying fixes it. This
    // list going stale silently is what broke the whole intake once already.
    let retiredModels = 0;

    for (const model of models) {
      // Up to 2 attempts per model if rate limited (429)
      const maxModelAttempts = 2;

      for (let attempt = 0; attempt < maxModelAttempts; attempt++) {
        if (attempt > 0) {
          console.warn(`[${label}] ${model} rate limited (429); backoff retry ${attempt}/${maxModelAttempts - 1} after 2500ms...`);
          await new Promise((r) => setTimeout(r, 2500));
        }

        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), timeoutMs);

        try {
          const response = await fetch(`${ENDPOINT(model)}?key=${this.apiKey}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [{ role: "user", parts }],
              ...(generationConfig ? { generationConfig } : {}),
            }),
            signal: controller.signal,
          });

          if (response.ok) {
            const data = await response.json();
            const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
            if (text && text.trim()) {
              return { text: text.trim(), model, error: null };
            }
            lastError = `${model}: empty response (possible safety block)`;
            break;
          } else {
            const body = await response.text();
            lastError = `${model}: HTTP ${response.status} ${body.slice(0, 200)}`;

            if (response.status === 429 && attempt < maxModelAttempts - 1) {
              // Retry this model after backoff
              continue;
            }

            if (response.status === 404) retiredModels += 1;

            if (!isModelLevelFailure(response.status)) {
              console.error(`[${label}] non-retryable Gemini error: ${lastError}`);
              return { text: null, model: null, error: lastError, fatal: true };
            }

            console.warn(`[${label}] ${model} unavailable, trying next: HTTP ${response.status}`);
            break;
          }
        } catch (err) {
          lastError =
            err.name === "AbortError"
              ? `${model}: timed out after ${timeoutMs}ms`
              : `${model}: ${err.message}`;
          console.warn(`[${label}] ${lastError}`);
          break;
        } finally {
          clearTimeout(timer);
        }
      }
    }

    if (retiredModels === models.length && models.length > 0) {
      console.error(
        `[${label}] EVERY model in the list is retired (HTTP 404): ${models.join(", ")}. ` +
          "This is not a transient outage — DEFAULT_MODELS in geminiClient.js needs updating. " +
          "Verify replacements with a real generateContent call; ListModels still lists retired ids."
      );
    }

    return { text: null, model: null, error: lastError, fatal: false };
  }
}

module.exports = new GeminiClient();
module.exports.DEFAULT_MODELS = DEFAULT_MODELS;
