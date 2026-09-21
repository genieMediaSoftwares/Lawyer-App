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

/**
 * Missing these degrades a feature but the server still serves.
 *
 * Entries removed from this list, and why — a warning that fires on every boot
 * for something nobody can act on trains people to ignore the log:
 *
 *  - CLOUDINARY_CLOUD_NAME: the integration was removed from the project, so
 *    the variable configures nothing. Warning about it was pure noise.
 *
 *  - ENCRYPTION_SECRET: satisfied by JWT_SECRET, which is already required
 *    above. See `satisfiedBy` below — it is only reported when BOTH are
 *    absent, which is the case that genuinely leaves field encryption on a
 *    development key.
 *
 *  - ADMIN_PASSWORD: not a server-configuration gap. seedAdmin skips cleanly
 *    without it and logs its own line saying so, so this warned a second time
 *    about something already reported by the code that cares.
 */
const RECOMMENDED = [
  ["GEMINI_API_KEY", "AI Smart Case analysis and the AI assistant"],
  [
    "ENCRYPTION_SECRET",
    "field encryption of lawyer payout details",
    // Documented fallback: cryptoUtil reads ENCRYPTION_SECRET || JWT_SECRET.
    { satisfiedBy: "JWT_SECRET" },
  ],
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

  const isSet = (name) => Boolean(String(process.env[name] || "").trim());

  const warnings = RECOMMENDED.filter(([name, , options]) => {
    if (isSet(name)) return false;
    // A documented alternative covers it, so nothing is actually degraded.
    if (options?.satisfiedBy && isSet(options.satisfiedBy)) return false;
    return true;
  }).map(([name, feature]) => `${name} is not set — ${feature} will be unavailable.`);

  return { warnings };
}

module.exports = { assertEnvironment };
