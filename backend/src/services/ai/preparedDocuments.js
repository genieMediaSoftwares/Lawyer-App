const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const UPLOAD_ROOT = path.join(__dirname, "../../../uploads");
const PREPARED_DIR = path.join(UPLOAD_ROOT, "ai-prepared");
const CASES_DIR = path.join(UPLOAD_ROOT, "cases");

// An optimized document waits here until the analysis that uses it is sent.
const MAX_AGE_MS = 2 * 60 * 60 * 1000;

const TOKEN_PATTERN = /^[a-f0-9]{32}$/;
const OWNER_PATTERN = /^[a-f0-9]{24}$/;

const pathsFor = (ownerId, token) => {
  const base = path.join(PREPARED_DIR, `${ownerId}-${token}`);
  return { file: `${base}.pdf`, meta: `${base}.json` };
};

async function moveFile(from, to) {
  try {
    await fs.promises.rename(from, to);
  } catch (error) {
    if (error.code !== "EXDEV") throw error;
    await fs.promises.copyFile(from, to);
    await fs.promises.unlink(from);
  }
}

async function save(ownerId, sourcePath, { originalName, mimeType }) {
  const owner = String(ownerId);
  if (!OWNER_PATTERN.test(owner)) throw new Error("Invalid owner.");

  await fs.promises.mkdir(PREPARED_DIR, { recursive: true });
  const token = crypto.randomBytes(16).toString("hex");
  const { file, meta } = pathsFor(owner, token);

  await moveFile(sourcePath, file);
  const size = (await fs.promises.stat(file)).size;
  await fs.promises.writeFile(
    meta,
    JSON.stringify({ originalName, mimeType, size, createdAt: Date.now() })
  );

  return { token, size };
}

/**
 * Hands a prepared document to an analysis, in the same shape multer gives
 * uploaded files. Returns null when the token is unknown, expired, or belongs
 * to someone else.
 */
async function claim(ownerId, token) {
  const owner = String(ownerId);
  const value = String(token ?? "");
  if (!OWNER_PATTERN.test(owner) || !TOKEN_PATTERN.test(value)) return null;

  const { file, meta } = pathsFor(owner, value);
  let details;
  try {
    details = JSON.parse(await fs.promises.readFile(meta, "utf8"));
    await fs.promises.access(file);
  } catch {
    return null;
  }

  if (Date.now() - Number(details.createdAt || 0) > MAX_AGE_MS) {
    await Promise.all([file, meta].map((p) => fs.promises.unlink(p).catch(() => {})));
    return null;
  }

  await fs.promises.mkdir(CASES_DIR, { recursive: true });
  const fileName = `${Date.now()}-${crypto.randomBytes(8).toString("hex")}.pdf`;
  const destination = path.join(CASES_DIR, fileName);
  await moveFile(file, destination);
  await fs.promises.unlink(meta).catch(() => {});

  return {
    path: destination,
    filename: fileName,
    originalname: details.originalName || "document.pdf",
    mimetype: details.mimeType || "application/pdf",
    size: (await fs.promises.stat(destination)).size,
  };
}

async function sweep(now = Date.now()) {
  let entries;
  try {
    entries = await fs.promises.readdir(PREPARED_DIR);
  } catch {
    return 0;
  }

  let removed = 0;
  for (const entry of entries) {
    const full = path.join(PREPARED_DIR, entry);
    try {
      const { mtimeMs } = await fs.promises.stat(full);
      if (now - mtimeMs > MAX_AGE_MS) {
        await fs.promises.unlink(full);
        removed += 1;
      }
    } catch {
      // Already gone.
    }
  }
  return removed;
}

module.exports = { save, claim, sweep, PREPARED_DIR, MAX_AGE_MS };
