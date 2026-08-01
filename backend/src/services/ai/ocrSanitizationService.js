const fs = require("fs");
const path = require("path");
const gemini = require("./geminiClient");

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

      if (ext === ".docx" || mimeType?.includes("wordprocessingml") || mimeType?.includes("docx")) {
        rawText = await this._extractDocxText(filePath);
      } else if (ext === ".pdf" || mimeType?.includes("pdf")) {
        const result = await this._extractPdfText(filePath);
        rawText = result.text;
        extractionFailed = result.extractionFailed;
        extractionError = result.error;
        if (result.isScanned) ocrQuality = "Scanned OCR";
      } else if ([".png", ".jpg", ".jpeg", ".webp"].includes(ext) || mimeType?.startsWith("image/")) {
        const result = await this._extractImageOcr(filePath, mimeType);
        rawText = result.text;
        extractionFailed = result.extractionFailed;
        extractionError = result.error;
      } else if (fs.existsSync(filePath)) {
        rawText = fs.readFileSync(filePath, "utf8");
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
   * PDF Text Extraction (Digital PDF text + Scanned PDF Vision fallback)
   */
  async _extractPdfText(filePath) {
    if (!fs.existsSync(filePath)) {
      return { text: "", isScanned: false, extractionFailed: true, error: "File not found on disk." };
    }

    const pdfBuffer = fs.readFileSync(filePath);

    // Cheap path first: pull literals out of uncompressed content streams.
    // Most real-world PDFs use FlateDecode, so this usually finds nothing and
    // we fall through to Gemini — but when it hits, it saves an API call.
    let textContent = "";
    try {
      const rawString = pdfBuffer.toString("latin1");
      const textMatches =
        rawString.match(/\((.*?)\)\s*Tj/g) || rawString.match(/\[(.*?)\]\s*TJ/g);
      if (textMatches && textMatches.length > 5) {
        textContent = textMatches
          .map((m) => m.replace(/[()[\]]/g, "").replace(/Tj|TJ/g, ""))
          .join(" ");
      }
    } catch {
      // Not fatal — fall through to OCR.
    }

    if (textContent.trim().length > 50) {
      return { text: textContent, isScanned: false, extractionFailed: false, error: null };
    }

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

    // Keep whatever the cheap path found, but report that OCR could not run.
    return { text: textContent, isScanned: true, extractionFailed: true, error };
  }

  /**
   * Extract raw text from DOCX document XML
   */
  async _extractDocxText(filePath) {
    if (!fs.existsSync(filePath)) return "";
    try {
      const buffer = fs.readFileSync(filePath);
      const str = buffer.toString("utf8");
      // Extract text inside XML <w:t> tags
      const matches = str.match(/<w:t[^>]*>(.*?)<\/w:t>/g);
      if (matches) {
        return matches.map((m) => m.replace(/<[^>]+>/g, "")).join(" ");
      }
    } catch (e) {
      console.error("DOCX extraction error:", e.message);
    }
    return "";
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
      /system\s*:/gi,
      /user\s*:/gi,
      /assistant\s*:/gi,
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
