const fs = require("fs");
const path = require("path");

class OcrSanitizationService {
  /**
   * Main entry point to extract text from a file (Image, PDF, DOCX)
   */
  async extractText(filePath, mimeType, originalName) {
    let rawText = "";
    let ocrQuality = "Good";
    const fraudFlags = [];

    try {
      const ext = path.extname(originalName || filePath).toLowerCase();
      const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_VISION_API_KEY;

      if (ext === ".docx" || mimeType?.includes("wordprocessingml") || mimeType?.includes("docx")) {
        rawText = await this._extractDocxText(filePath);
      } else if (ext === ".pdf" || mimeType?.includes("pdf")) {
        const result = await this._extractPdfText(filePath, apiKey);
        rawText = result.text;
        if (result.isScanned) ocrQuality = "Scanned OCR";
      } else if ([".png", ".jpg", ".jpeg", ".webp"].includes(ext) || mimeType?.startsWith("image/")) {
        rawText = await this._extractImageOcr(filePath, apiKey);
      } else {
        // Fallback text read
        if (fs.existsSync(filePath)) {
          rawText = fs.readFileSync(filePath, "utf8");
        }
      }

      // Detect Quality / Fraud Indicators
      const cleanLen = rawText.trim().length;
      if (cleanLen < 15) {
        ocrQuality = "Low Confidence";
        fraudFlags.push(`Low text density detected in file '${originalName}'. The image or scan may be blurred or unreadable.`);
      }

      const sanitizedText = this.sanitizeText(rawText);

      return {
        extractedText: sanitizedText,
        ocrQuality,
        fraudFlags,
        charCount: cleanLen,
      };
    } catch (err) {
      console.error(`OCR Extraction error for ${originalName}:`, err.message);
      return {
        extractedText: `[Document Content from ${originalName}]`,
        ocrQuality: "Failed",
        fraudFlags: [`Unable to fully process document '${originalName}': ${err.message}`],
        charCount: 0,
      };
    }
  }

  /**
   * Google Vision API OCR REST Call for Images
   */
  async _extractImageOcr(filePath, apiKey) {
    if (!fs.existsSync(filePath)) return "";
    const imageBuffer = fs.readFileSync(filePath);
    const base64Content = imageBuffer.toString("base64");

    if (apiKey) {
      try {
        const res = await fetch(
          `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              requests: [
                {
                  image: { content: base64Content },
                  features: [{ type: "TEXT_DETECTION" }],
                },
              ],
            }),
          }
        );

        if (res.ok) {
          const data = await res.json();
          const annotations = data.responses?.[0]?.textAnnotations;
          if (annotations && annotations.length > 0) {
            return annotations[0].description || "";
          }
        }
      } catch (e) {
        console.warn("Vision API REST request failed, attempting Gemini OCR fallback:", e.message);
      }

      // Gemini Vision Fallback for OCR
      try {
        const geminiRes = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [
                {
                  role: "user",
                  parts: [
                    {
                      inlineData: {
                        mimeType: "image/jpeg",
                        data: base64Content,
                      },
                    },
                    {
                      text: "Extract all legible text from this legal document image verbatim. Return ONLY the extracted text.",
                    },
                  ],
                },
              ],
            }),
          }
        );

        if (geminiRes.ok) {
          const geminiData = await geminiRes.json();
          const text = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
          if (text) return text;
        }
      } catch (err) {
        console.error("Gemini Vision OCR fallback failed:", err.message);
      }
    }

    return "";
  }

  /**
   * PDF Text Extraction (Digital PDF text + Scanned PDF Vision fallback)
   */
  async _extractPdfText(filePath, apiKey) {
    if (!fs.existsSync(filePath)) return { text: "", isScanned: false };
    const pdfBuffer = fs.readFileSync(filePath);

    // Attempt digital text extraction from PDF stream/string
    let textContent = "";
    try {
      const rawString = pdfBuffer.toString("utf8");
      const textMatches = rawString.match(/\((.*?)\)\s*Tj/g) || rawString.match(/\[(.*?)\]\s*TJ/g);
      if (textMatches && textMatches.length > 5) {
        textContent = textMatches
          .map((m) => m.replace(/[\(\)\[\]]/g, "").replace(/Tj|TJ/g, ""))
          .join(" ");
      }
    } catch (e) {
      // ignore
    }

    if (textContent.trim().length > 50) {
      return { text: textContent, isScanned: false };
    }

    // If PDF text extraction is minimal (scanned PDF), use Gemini Vision OCR
    if (apiKey) {
      try {
        const base64Pdf = pdfBuffer.toString("base64");
        const res = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [
                {
                  role: "user",
                  parts: [
                    {
                      inlineData: {
                        mimeType: "application/pdf",
                        data: base64Pdf,
                      },
                    },
                    {
                      text: "Extract all text from this scanned legal PDF document page by page. Return ONLY the text.",
                    },
                  ],
                },
              ],
            }),
          }
        );

        if (res.ok) {
          const data = await res.json();
          const extracted = data.candidates?.[0]?.content?.parts?.[0]?.text;
          if (extracted) {
            return { text: extracted, isScanned: true };
          }
        }
      } catch (err) {
        console.error("PDF Vision OCR error:", err.message);
      }
    }

    return { text: textContent, isScanned: true };
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
