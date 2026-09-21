const DEFAULT_MODELS = [
  "gemini-3.5-flash-lite",
  "gemini-flash-lite-latest",
  "gemini-3.1-flash-lite",
  "gemini-3.5-flash",
  "gemini-flash-latest",
];

const ENDPOINT = (model) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

const isModelLevelFailure = (status) =>
  status === 404 || status === 429 || status === 500 || status === 503;

class GeminiClient {
  get apiKey() {
    return process.env.GEMINI_API_KEY;
  }

  get isConfigured() {
    return Boolean(this.apiKey);
  }

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

      if (result.fatal) return { text: null, model: null, error: result.error };

      lastError = result.error;
    }

    console.error(`[${label}] all Gemini models failed after ${passes} passes. Last error: ${lastError}`);
    return { text: null, model: null, error: lastError };
  }

  async _attemptPass(parts, models, timeoutMs, label, generationConfig) {
    let lastError = null;
    let retiredModels = 0;

    for (const model of models) {
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
