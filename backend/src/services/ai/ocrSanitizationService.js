const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const gemini = require("./geminiClient");
const { extractDocxText } = require("./docxExtractor");

/**
 * Formats we can actually turn into text, and how. Anything absent is rejected
 * with a message naming the file, rather than being read as UTF-8 and fed to
 * the model as if binary noise were the document's contents.
 *
 * `.doc` (the pre-2007 binary Word format) is deliberately absent: it is a
 * compound-file container, Gemini does not accept it, and reading it as text
 * yields garbage. The upload middleware and the picker both refuse it.
 */
const TEXT_EXTENSIONS = new Set([".txt", ".text", ".md", ".csv", ".rtf"]);
const IMAGE_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".webp", ".heic", ".heif"]);

class OcrSanitizationService {
  /**
   * Main entry point to extract text from a file (Image, PDF, DOCX).
   *
   * Returns `extractionFailed: true` when the OCR pipeline itself could not
   * run (no API key, model unavailable, network error). That is deliberately
   * distinct from "we read the document and it contained little text" — the
   * two used to be conflated, so an outage produced fraud flags accusing the
   * client's paperwork of being altered or unreadable.
   */
  async extractText(filePath, mimeType, originalName) {
    let rawText = "";
    let ocrQuality = "Good";
    let extractionFailed = false;
    let extractionError = null;
    const fraudFlags = [];

    try {
      const ext = path.extname(originalName || filePath).toLowerCase();

      if (ext === ".docx" || mimeType?.includes("wordprocessingml")) {
        const result = this._extractDocx(filePath);
        rawText = result.text;
        extractionFailed = result.extractionFailed;
        extractionError = result.error;
      } else if (ext === ".pdf" || mimeType?.includes("pdf")) {
        const result = await this._extractPdfText(filePath);
        rawText = result.text;
        extractionFailed = result.extractionFailed;
        extractionError = result.error;
        if (result.isScanned) ocrQuality = "Scanned OCR";
      } else if (IMAGE_EXTENSIONS.has(ext) || mimeType?.startsWith("image/")) {
        const result = await this._extractImageOcr(filePath, mimeType);
        rawText = result.text;
        extractionFailed = result.extractionFailed;
        extractionError = result.error;
      } else if (TEXT_EXTENSIONS.has(ext) || mimeType?.startsWith("text/")) {
        rawText = fs.existsSync(filePath) ? fs.readFileSync(filePath, "utf8") : "";
        if (!fs.existsSync(filePath)) {
          extractionFailed = true;
          extractionError = "File not found on disk.";
        }
      } else {
        // Never fall back to reading unknown bytes as UTF-8. That is how a
        // legacy .doc used to reach the model as several kilobytes of binary
        // noise dressed up as the client's document.
        extractionFailed = true;
        extractionError = `Unsupported file type "${ext || mimeType || "unknown"}". Upload a PDF, image, DOCX or TXT.`;
      }

      const cleanLen = rawText.trim().length;

      if (extractionFailed) {
        // Our problem, not the document's. Say so plainly and raise no flag.
        ocrQuality = "Extraction Unavailable";
      } else if (cleanLen < 15) {
        // We did read it, and there genuinely was almost no text.
        ocrQuality = "Low Confidence";
        fraudFlags.push(
          `Very little readable text found in '${originalName}'. If this document should contain text, it may be blurred, skewed or a low-quality scan.`
        );
      }

      return {
        extractedText: this.sanitizeText(rawText),
        ocrQuality,
        fraudFlags,
        charCount: cleanLen,
        extractionFailed,
        extractionError,
      };
    } catch (err) {
      console.error(`OCR Extraction error for ${originalName}:`, err.message);
      return {
        // Must NOT be a human-readable placeholder: the old
        // "[Document Content from x.pdf]" string was fed to the model as if
        // it were the document, which is what let it invent case details.
        extractedText: "",
        ocrQuality: "Extraction Unavailable",
        fraudFlags: [],
        charCount: 0,
        extractionFailed: true,
        extractionError: err.message,
      };
    }
  }

  /**
   * Image OCR via Gemini vision.
   *
   * The previous implementation called vision.googleapis.com first. That
   * endpoint rejects API-key auth outright ("API keys are not supported by
   * this API. Expected OAuth2 access token"), so it could never succeed with
   * GEMINI_API_KEY and only added a failed round trip per image. Removed.
   */
  async _extractImageOcr(filePath, mimeType) {
    if (!fs.existsSync(filePath)) {
      return { text: "", extractionFailed: true, error: "File not found on disk." };
    }

    const base64Content = fs.readFileSync(filePath).toString("base64");

    const { text, error } = await gemini.generate(
      [
        {
          inlineData: {
            // Was hardcoded to image/jpeg, which mislabels every PNG and WebP.
            mimeType: this._normalizeImageMime(mimeType, filePath),
            data: base64Content,
          },
        },
        {
          text:
            "Extract all legible text from this legal document image verbatim. " +
            "Return ONLY the extracted text, with no commentary. " +
            "If the image contains no readable text, return an empty response.",
        },
      ],
      { label: "ocr:image" }
    );

    return { text: text || "", extractionFailed: text === null, error };
  }

  /**
   * Gemini requires a real image MIME type; derive one rather than assuming.
   */
  _normalizeImageMime(mimeType, filePath) {
    const supported = ["image/png", "image/jpeg", "image/webp", "image/heic", "image/heif"];
    if (mimeType && supported.includes(mimeType)) return mimeType;

    switch (path.extname(filePath).toLowerCase()) {
      case ".png":
        return "image/png";
      case ".webp":
        return "image/webp";
      default:
        return "image/jpeg";
    }
  }

  /**
   * Fast offline extraction for digital PDFs using FlateDecode decompression.
   */
  _extractDigitalPdfText(pdfBuffer) {
    try {
      const rawString = pdfBuffer.toString("latin1");

      const literalMatches =
        rawString.match(/\((.*?)\)\s*Tj/g) || rawString.match(/\[(.*?)\]\s*TJ/g);
      if (literalMatches && literalMatches.length > 5) {
        const text = literalMatches
          .map((m) => m.replace(/[()[\]]/g, "").replace(/Tj|TJ/g, "").trim())
          .filter(Boolean)
          .join(" ");
        if (this._looksLikeProse(text)) return text;
      }

      const streamRegex = /stream\r?\n([\s\S]*?)\r?\nendstream/g;
      let match;
      const decompressedParts = [];

      while ((match = streamRegex.exec(rawString)) !== null) {
        const chunk = match[1];
        if (!chunk || chunk.length < 10) continue;
        try {
          const buf = Buffer.from(chunk, "latin1");
          const inflated = zlib.unzipSync(buf).toString("latin1");
          decompressedParts.push(inflated);
        } catch {
          if (chunk.includes("BT") && chunk.includes("ET")) {
            decompressedParts.push(chunk);
          }
        }
      }

      if (decompressedParts.length > 0) {
        const fullDecompressed = decompressedParts.join("\n");
        const matches =
          fullDecompressed.match(/\((.*?)\)\s*Tj/g) ||
          fullDecompressed.match(/\[(.*?)\]\s*TJ/g) ||
          fullDecompressed.match(/[A-Za-z0-9\s.,;:'"()-]{15,}/g);

        if (matches && matches.length > 0) {
          const text = matches
            .map((m) => m.replace(/[()[\]]/g, "").replace(/Tj|TJ/g, "").trim())
            .filter((s) => s.length > 2)
            .join(" ");
          if (this._looksLikeProse(text)) return text;
        }
      }
    } catch (_) {}
    return "";
  }

  /**
   * PDF Text Extraction (Digital PDF text + Scanned PDF Vision fallback)
   */
  async _extractPdfText(filePath) {
    if (!fs.existsSync(filePath)) {
      return { text: "", isScanned: false, extractionFailed: true, error: "File not found on disk." };
    }

    const pdfBuffer = fs.readFileSync(filePath);

    // Fast path: Digital PDF stream decompression
    let textContent = this._extractDigitalPdfText(pdfBuffer);
    if (this._looksLikeProse(textContent)) {
      return { text: textContent, isScanned: false, extractionFailed: false, error: null };
    }
    textContent = "";

    // Gemini accepts PDFs directly and handles scanned pages.
    const { text, error } = await gemini.generate(
      [
        { inlineData: { mimeType: "application/pdf", data: pdfBuffer.toString("base64") } },
        {
          text:
            "Extract all text from this legal PDF document, page by page, verbatim. " +
            "Return ONLY the extracted text, with no commentary.",
        },
      ],
      { label: "ocr:pdf" }
    );

    if (text) {
      return { text, isScanned: true, extractionFailed: false, error: null };
    }

    // Fallback: If Gemini OCR fails (e.g. rate limits), attempt fallback text extraction
    if (!textContent) {
      try {
        const rawString = pdfBuffer.toString("latin1");
        const matches = rawString.match(/[A-Za-z0-9\s.,;:'"()-]{15,}/g);
        if (matches && matches.length > 0) {
          const extractedFallback = matches.filter((s) => s.trim().length > 20).join("\n");
          if (this._looksLikeProse(extractedFallback)) {
            textContent = extractedFallback;
          }
        }
      } catch (_) {}
    }

    return {
      text: textContent,
      isScanned: true,
      extractionFailed: !textContent,
      error: error || (textContent ? null : "OCR service unavailable"),
    };
  }

  /**
   * DOCX text via a real ZIP + inflate pass — see services/ai/docxExtractor.js
   * for why regexing the raw file could never work.
   */
  _extractDocx(filePath) {
    if (!fs.existsSync(filePath)) {
      return { text: "", extractionFailed: true, error: "File not found on disk." };
    }

    try {
      const text = extractDocxText(fs.readFileSync(filePath));
      return { text, extractionFailed: false, error: null };
    } catch (e) {
      // A corrupt or mislabelled archive is our failure to read it, not
      // evidence that the client's document is blank.
      console.error("DOCX extraction error:", e.message);
      return { text: "", extractionFailed: true, error: e.message };
    }
  }

  /**
   * Guards the PDF fast path: is this recovered string plausibly human text?
   *
   * Requires enough length, a high proportion of printable characters, and a
   * realistic letter-to-total ratio. Inflated binary fails all three, so it
   * falls through to Gemini OCR instead of being reported as the document.
   */
  _looksLikeProse(candidate) {
    const text = (candidate || "").trim();
    if (text.length < 80) return false;

    const printable = (text.match(/[\x20-\x7E\s]/g) || []).length;
    if (printable / text.length < 0.92) return false;

    const letters = (text.match(/[A-Za-z]/g) || []).length;
    if (letters / text.length < 0.5) return false;

    // Real prose contains words. Binary that survives the checks above is
    // typically an unbroken run of symbols.
    const words = text.split(/\s+/).filter((w) => /^[A-Za-z][A-Za-z'.,-]{2,}$/.test(w));
    return words.length >= 12;
  }

  /**
   * Sanitizes OCR text to prevent Prompt Injection attacks
   */
  sanitizeText(text) {
    if (!text || typeof text !== "string") return "";

    let sanitized = text;

    // Strip known prompt injection directives
    const injectionPatterns = [
      /ignore\s+previous\s+instructions/gi,
      /ignore\s+all\s+instructions/gi,
      // Anchored to line starts. Unanchored, these matched ordinary legal
      // prose — "…before the Assistant: Commissioner of Police…" and any
      // sentence ending in "the user:" — and redacted the client's own
      // document. A role-prefix injection only works at the start of a line.
      /^[ \t]*system\s*:/gim,
      /^[ \t]*user\s*:/gim,
      /^[ \t]*assistant\s*:/gim,
      /\[INST\]/gi,
      /\[\/INST\]/gi,
      /<\|endoftext\|>/gi,
      /you\s+are\s+now\s+a/gi,
      /override\s+system\s+prompt/gi,
    ];

    for (const pattern of injectionPatterns) {
      sanitized = sanitized.replace(pattern, "[CLEANED_INJECTION_ATTEMPT]");
    }

    // Limit length to avoid prompt token explosion (e.g., max 15,000 characters)
    if (sanitized.length > 15000) {
      sanitized = sanitized.substring(0, 15000) + "... [Text truncated for processing limit]";
    }

    return sanitized.trim();
  }
}

module.exports = new OcrSanitizationService();
