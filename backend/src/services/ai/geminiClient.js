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
 * Models tried in order. Ordering matters, and was chosen by probing the key:
 *  - `gemini-flash-latest` is an alias Google keeps pointed at a live model,
 *    so it survives model retirements. Occasionally returns 503 under load.
 *  - `gemini-3.5-flash` is the pinned backup and answered reliably in testing.
 *  - `gemini-2.0-flash` is last on purpose: it currently has zero quota on
 *    this project (HTTP 429, "limit: 0"), so trying it earlier burns a round
 *    trip on every single call. It stays in the list so it resumes serving
 *    traffic automatically once billing is sorted.
 *  - `gemini-1.5-flash` was removed entirely: it returns 404 (retired).
 */
const DEFAULT_MODELS = [
  "gemini-flash-latest",
  "gemini-3.5-flash",
  "gemini-2.0-flash",
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
   * @returns {Promise<{text: string|null, model: string|null, error: string|null}>}
   *   Never throws. Callers decide whether an empty result is fatal.
   */
  async generate(parts, options = {}) {
    const {
      models = DEFAULT_MODELS,
      timeoutMs = 60000,
      label = "gemini",
      // Two passes over the model list. Observed in testing: the healthy
      // models intermittently return 503/UNAVAILABLE, and occasionally all of
      // them do at the same instant — which failed the user's whole intake for
      // a blip that clears in a second. A second pass costs nothing when the
      // first succeeds.
      passes = 2,
      passDelayMs = 1500,
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

      const result = await this._attemptPass(parts, models, timeoutMs, label);
      if (result.text !== null) return result;

      // A non-retryable request-level error will fail identically next pass.
      if (result.fatal) return { text: null, model: null, error: result.error };

      lastError = result.error;
    }

    console.error(`[${label}] all Gemini models failed after ${passes} passes. Last error: ${lastError}`);
    return { text: null, model: null, error: lastError };
  }

  /** One walk through the model list. */
  async _attemptPass(parts, models, timeoutMs, label) {
    let lastError = null;

    for (const model of models) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);

      try {
        const response = await fetch(`${ENDPOINT(model)}?key=${this.apiKey}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ contents: [{ role: "user", parts }] }),
          signal: controller.signal,
        });

        if (response.ok) {
          const data = await response.json();
          const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
          if (text && text.trim()) {
            return { text: text.trim(), model, error: null };
          }
          // A 200 with no candidate usually means a safety block; another
          // model is unlikely to help, but it is cheap to let the loop try.
          lastError = `${model}: empty response (possible safety block)`;
        } else {
          const body = await response.text();
          lastError = `${model}: HTTP ${response.status} ${body.slice(0, 200)}`;

          if (!isModelLevelFailure(response.status)) {
            // Request-level problem (e.g. 400 malformed, 403 bad key). Every
            // model and every pass would fail identically — stop here.
            console.error(`[${label}] non-retryable Gemini error: ${lastError}`);
            return { text: null, model: null, error: lastError, fatal: true };
          }
          console.warn(`[${label}] ${model} unavailable, trying next: HTTP ${response.status}`);
        }
      } catch (err) {
        lastError =
          err.name === "AbortError"
            ? `${model}: timed out after ${timeoutMs}ms`
            : `${model}: ${err.message}`;
        console.warn(`[${label}] ${lastError}`);
      } finally {
        clearTimeout(timer);
      }
    }

    return { text: null, model: null, error: lastError, fatal: false };
  }
}

module.exports = new GeminiClient();
module.exports.DEFAULT_MODELS = DEFAULT_MODELS;
