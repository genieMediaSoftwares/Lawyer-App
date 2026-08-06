/**
 * Startup configuration check.
 *
 * This file was previously empty and nothing validated the environment, so a
 * deployment missing a variable started cleanly and then failed one request at
 * a time: no JWT_SECRET meant every sign-in returned a 500, and an empty
 * ALLOWED_ORIGINS meant production CORS rejected the app itself. Both look like
 * application bugs from the outside and are slow to trace back to a missing
 * line in .env.
 *
 * Checking at boot turns those into one clear message before the port opens.
 * Nothing here changes runtime behaviour when the environment is complete.
 */

/** Variables the server genuinely cannot run correctly without. */
const REQUIRED_ALWAYS = [
  ["MONGO_URI", "the database connection string"],
  ["JWT_SECRET", "the token signing secret — no sign-in works without it"],
];

/** Additionally required once NODE_ENV=production. */
const REQUIRED_IN_PRODUCTION = [
  [
    "ALLOWED_ORIGINS",
    "the comma-separated CORS allowlist — production rejects every origin when it is empty",
  ],
];

/** Missing these degrades a feature but the server still serves. */
const RECOMMENDED = [
  ["GEMINI_API_KEY", "AI Smart Case analysis and the AI assistant"],
  ["CLOUDINARY_CLOUD_NAME", "remote media storage"],
  ["ENCRYPTION_SECRET", "field encryption (falls back to JWT_SECRET)"],
  ["ADMIN_PASSWORD", "seeding the initial admin account"],
];

/**
 * Verifies configuration and throws on anything fatal.
 *
 * @returns {{warnings: string[]}} Non-fatal gaps, for the caller to log.
 */
function assertEnvironment() {
  const isProduction = process.env.NODE_ENV === "production";

  const required = isProduction
    ? [...REQUIRED_ALWAYS, ...REQUIRED_IN_PRODUCTION]
    : REQUIRED_ALWAYS;

  const missing = required.filter(([name]) => !String(process.env[name] || "").trim());

  if (missing.length > 0) {
    const detail = missing.map(([name, why]) => `  - ${name}: ${why}`).join("\n");
    throw new Error(
      `Missing required environment variable(s):\n${detail}\n` +
        `Set them in the server's .env (see backend/.env.example) and restart.`
    );
  }

  const warnings = RECOMMENDED.filter(
    ([name]) => !String(process.env[name] || "").trim()
  ).map(([name, feature]) => `${name} is not set — ${feature} will be unavailable.`);

  return { warnings };
}

module.exports = { assertEnvironment };
