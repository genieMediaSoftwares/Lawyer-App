const REQUIRED_ALWAYS = [
  ["MONGO_URI", "the database connection string"],
  ["JWT_SECRET", "the token signing secret — no sign-in works without it"],
];

const REQUIRED_IN_PRODUCTION = [
  [
    "ALLOWED_ORIGINS",
    "the comma-separated CORS allowlist — production rejects every origin when it is empty",
  ],
];

const RECOMMENDED = [
  ["GEMINI_API_KEY", "AI Smart Case analysis and the AI assistant"],
  [
    "ENCRYPTION_SECRET",
    "field encryption of lawyer payout details",
    { satisfiedBy: "JWT_SECRET" },
  ],
];

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
    if (options?.satisfiedBy && isSet(options.satisfiedBy)) return false;
    return true;
  }).map(([name, feature]) => `${name} is not set — ${feature} will be unavailable.`);

  return { warnings };
}

module.exports = { assertEnvironment };
