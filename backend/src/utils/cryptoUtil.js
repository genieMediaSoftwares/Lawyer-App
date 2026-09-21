const crypto = require("crypto");

const ALGORITHM = "aes-256-gcm";

function resolveSecret() {
  const configured = process.env.ENCRYPTION_SECRET || process.env.JWT_SECRET;
  if (configured) return configured;

  if (process.env.NODE_ENV === "production") {
    throw new Error(
      "ENCRYPTION_SECRET (or JWT_SECRET) must be set in production. " +
        "Refusing to start with a default key — stored data would not be protected."
    );
  }

  console.warn(
    "[cryptoUtil] No ENCRYPTION_SECRET/JWT_SECRET set. Using a development-only key. " +
      "Data encrypted now cannot be read by a deployment with a real secret."
  );
  return "development-only-insecure-key";
}

const SECRET_KEY = crypto.createHash("sha256").update(resolveSecret()).digest();

function encrypt(text) {
  if (!text || typeof text !== "string") return text;
  if (text.startsWith("enc:")) return text;

  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGORITHM, SECRET_KEY, iv);
  let encrypted = cipher.update(text, "utf8", "hex");
  encrypted += cipher.final("hex");
  const authTag = cipher.getAuthTag().toString("hex");

  return `enc:${iv.toString("hex")}:${authTag}:${encrypted}`;
}

function decrypt(text) {
  if (!text || typeof text !== "string" || !text.startsWith("enc:")) return text;

  try {
    const parts = text.slice(4).split(":");
    if (parts.length !== 3) return text;
    const [ivHex, authTagHex, encryptedHex] = parts;

    const iv = Buffer.from(ivHex, "hex");
    const authTag = Buffer.from(authTagHex, "hex");
    const decipher = crypto.createDecipheriv(ALGORITHM, SECRET_KEY, iv);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(encryptedHex, "hex", "utf8");
    decrypted += decipher.final("utf8");
    return decrypted;
  } catch (err) {
    console.error("Decryption error:", err.message);
    return text;
  }
}

module.exports = { encrypt, decrypt };
