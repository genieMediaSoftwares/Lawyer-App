const { execFile } = require("child_process");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");

const { AI_MAX_FILE_BYTES } = require("../../config/uploadLimits");

const PASS_TIMEOUT_MS = 90 * 1000;

// Only embedded images are resampled. Text, fonts and vector content are
// rewritten as-is, so the legal wording of the document never changes.
// Black-and-white scans keep 300 dpi, which OCR needs to read them.
const PASSES = [
  { name: "standard", resolution: 150 },
  { name: "strong", resolution: 110 },
];

class PdfOptimizationError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = "PdfOptimizationError";
    this.code = code;
    Object.assign(this, details);
  }
}

const candidateBinaries = () => {
  if (process.env.GHOSTSCRIPT_PATH) return [process.env.GHOSTSCRIPT_PATH];
  return process.platform === "win32" ? ["gswin64c", "gswin32c"] : ["gs"];
};

const run = (binary, args, timeout) =>
  new Promise((resolve, reject) => {
    execFile(binary, args, { timeout, windowsHide: true }, (error, stdout) => {
      if (error) reject(error);
      else resolve(stdout);
    });
  });

let cachedBinary;

async function findGhostscript() {
  if (cachedBinary !== undefined) return cachedBinary;
  for (const binary of candidateBinaries()) {
    try {
      await run(binary, ["--version"], 10 * 1000);
      cachedBinary = binary;
      return binary;
    } catch {
      // Try the next candidate.
    }
  }
  cachedBinary = null;
  return null;
}

const resetGhostscriptCache = () => {
  cachedBinary = undefined;
};

const ghostscriptArgs = (input, output, resolution) => [
  "-sDEVICE=pdfwrite",
  "-dCompatibilityLevel=1.5",
  "-dPDFSETTINGS=/ebook",
  "-dSAFER",
  "-dBATCH",
  "-dNOPAUSE",
  "-dQUIET",
  "-dDetectDuplicateImages=true",
  "-dCompressFonts=true",
  "-dDownsampleColorImages=true",
  "-dDownsampleGrayImages=true",
  "-dDownsampleMonoImages=true",
  `-dColorImageResolution=${resolution}`,
  `-dGrayImageResolution=${resolution}`,
  "-dMonoImageResolution=300",
  `-sOutputFile=${output}`,
  input,
];

async function hasPdfHeader(filePath) {
  const handle = await fs.promises.open(filePath, "r");
  try {
    const buffer = Buffer.alloc(5);
    await handle.read(buffer, 0, 5, 0);
    return buffer.toString("latin1") === "%PDF-";
  } finally {
    await handle.close();
  }
}

const removeQuietly = (filePath) =>
  filePath ? fs.promises.unlink(filePath).catch(() => {}) : Promise.resolve();

const formatMb = (bytes) => `${(bytes / (1024 * 1024)).toFixed(1)} MB`;

/**
 * Shrinks a PDF until it fits targetBytes, trying progressively stronger
 * passes. Returns the path of the file to keep: the input itself when it
 * already fits, otherwise a new temporary file the caller owns.
 */
async function optimizePdf(inputPath, { targetBytes = AI_MAX_FILE_BYTES } = {}) {
  const originalSize = (await fs.promises.stat(inputPath)).size;

  if (!(await hasPdfHeader(inputPath))) {
    throw new PdfOptimizationError("INVALID_PDF", "This file is not a valid PDF.");
  }

  if (originalSize <= targetBytes) {
    return { path: inputPath, size: originalSize, originalSize, optimized: false, passes: 0 };
  }

  const binary = await findGhostscript();
  if (!binary) {
    throw new PdfOptimizationError(
      "UNAVAILABLE",
      "PDF optimization is not available on the server right now. Please upload a PDF of 3 MB or less."
    );
  }

  let best = null;
  let passes = 0;

  for (const pass of PASSES) {
    const output = path.join(
      os.tmpdir(),
      `pdf-opt-${crypto.randomBytes(8).toString("hex")}.pdf`
    );
    passes += 1;

    try {
      await run(binary, ghostscriptArgs(inputPath, output, pass.resolution), PASS_TIMEOUT_MS);
      if (!(await hasPdfHeader(output))) throw new Error("Output is not a PDF.");
      const size = (await fs.promises.stat(output)).size;
      if (size <= 0) throw new Error("Output is empty.");

      if (!best || size < best.size) {
        if (best) await removeQuietly(best.path);
        best = { path: output, size };
      } else {
        await removeQuietly(output);
      }
    } catch {
      await removeQuietly(output);
      continue;
    }

    if (best.size <= targetBytes) break;
  }

  if (!best) {
    throw new PdfOptimizationError(
      "FAILED",
      "This PDF could not be optimized. It may be password-protected or damaged."
    );
  }

  if (best.size > targetBytes) {
    await removeQuietly(best.path);
    throw new PdfOptimizationError(
      "STILL_TOO_LARGE",
      `This PDF is ${formatMb(originalSize)} and could only be reduced to ${formatMb(
        best.size
      )}, which is still over the ${formatMb(targetBytes)} limit. Please upload fewer pages or split it into smaller PDFs.`,
      { bestSize: best.size }
    );
  }

  return { path: best.path, size: best.size, originalSize, optimized: true, passes };
}

module.exports = {
  optimizePdf,
  findGhostscript,
  resetGhostscriptCache,
  PdfOptimizationError,
  PASSES,
};
