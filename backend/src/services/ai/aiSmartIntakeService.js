const gemini = require("./geminiClient");
const taxonomy = require("../../config/legalCategories");
const fs = require("fs");
const path = require("path");

/**
 * Below this the model's own confidence is not good enough to pre-fill a field
 * that will end up on a filed legal case. Such fields are still returned, but
 * listed in `needsReview` so the form leaves them blank and asks the client.
 */
const CONFIDENCE_FLOOR = 0.55;

/**
 * Total base64 budget for inline document payloads in one request, and the cap
 * on how many files may be attached.
 *
 * Every uploaded document reaches the model — the ones whose text extracted
 * cleanly through their OCR text, and the ones that did not through these
 * inline bytes. The budget exists because base64 inflates a file by ~33% and
 * Gemini rejects oversized requests outright; it is spent on the documents
 * that need vision most, not on the first two in the list.
 */
const INLINE_BUDGET_BYTES = 14 * 1024 * 1024;
const INLINE_MAX_FILES = 6;

/**
 * Structured extraction for the Post Case form.
 */
class AiSmartIntakeService {
  /**
   * @param {object[]} [priorityFiles] Files whose OCR failed or returned almost
   *   nothing. These are attached inline first, because they are exactly the
   *   documents the text channel failed to represent.
   * @returns {Promise<{extracted: object, warnings: string[]}>}
   */
  async extractCaseData({
    ocrText,
    voiceTranscript,
    typedDescription,
    documentMetadata,
    documentFiles,
    priorityFiles,
  }) {
    const sourceText = `
=== CLIENT'S OWN DESCRIPTION (most authoritative) ===
${typedDescription || "None provided."}

=== VOICE TRANSCRIPT ===
${voiceTranscript || "None provided."}

=== EXTRACTED DOCUMENT TEXT ===
${ocrText || "No document text could be extracted."}

=== ATTACHED DOCUMENT METADATA ===
${JSON.stringify(documentMetadata || [], null, 2)}
`;

    const prompt = `You are a legal intake assistant for an Indian legal services app.
Read the client's documents and description, then extract ONLY the facts that are actually present.

Return a SINGLE VALID JSON OBJECT and nothing else. No markdown fences, no commentary.

CRITICAL RULES:
1. Use null for any field you cannot determine from the source text or documents. NEVER invent,
   infer or fill a plausible-looking placeholder. A null is correct and expected.
2. "category" MUST be copied EXACTLY from the list below, character for character.
   "subType" MUST be one of that category's listed sub-types, copied exactly.
   If nothing fits, set both to null.
3. Dates must be ISO 8601 (YYYY-MM-DD). If only a month/year is known, use the
   first day of that month. If no date is stated, null.
4. The CLIENT'S OWN DESCRIPTION outranks the document text. An uploaded file may
   be unrelated to the matter (a resume, an ID scan, a random photo). If the
   document does not concern the problem the client described, base the case
   fields on the client's description and ignore the document's subject matter —
   record what the file appears to be in "documentType" only.

ALLOWED CATEGORIES AND SUB-TYPES:
${taxonomy.promptTaxonomy()}

5. "confidence" must carry an honest 0-1 score for every field you filled.
   Score how certain you are that the value is correct FOR THIS CLIENT'S
   MATTER — not how clearly you read the characters. A name read perfectly
   off a document that may belong to a different matter is LOW confidence.
   Do not include a score for a field you set to null.

JSON SCHEMA:
{
  "title": "Short factual case title, max 12 words, or null",
  "description": "Factual summary of what happened: parties, amounts, places, dates. No legal advice, no speculation. Or null.",
  "summary": "2-4 sentence neutral synopsis of the matter for the client to review, or null",
  "category": "EXACT category from the list above, or null",
  "subType": "EXACT sub-type belonging to that category, or null",
  "urgency": "Urgent | High | Medium | Flexible | null",
  "city": "City or town name only, or null",
  "state": "State name only, or null",
  "location": "Fuller address/locality if one is stated, or null",
  "court": "Named court if the documents mention one, or null",
  "incidentDate": "YYYY-MM-DD of when the incident happened, or null",
  "opposingParty": "Name of the single main opposing party, or null",
  "parties": [
    {"name": "Party name exactly as written", "role": "Their role, e.g. Complainant, Accused, Landlord, Employer, Bank, Petitioner"}
  ],
  "firNumber": "FIR number or existing court case number, or null. Only for criminal/cyber/accident matters.",
  "policeStation": "Police station name, or null. Only for criminal/cyber/accident matters.",
  "bailDetails": "Bail status, bail type and any sections charged, as a short phrase. Or null. Only for criminal matters.",
  "claimAmount": "Numeric amount in INR if a sum is claimed or disputed, else null",
  "documentType": "What the uploaded document appears to be (FIR, Sale Deed, Legal Notice, Agreement, Bank Memo, Medical Report, ...), or null",
  "confidence": {"title": 0.0, "description": 0.0, "category": 0.0, "subType": 0.0, "city": 0.0, "state": 0.0, "location": 0.0, "court": 0.0, "incidentDate": 0.0, "opposingParty": 0.0, "firNumber": 0.0, "policeStation": 0.0, "bailDetails": 0.0, "claimAmount": 0.0, "urgency": 0.0},
  "unreadableDocumentNotes": ["Short notes about pages that could not be read, empty array if none"]
}`;

    const parts = [];

    // Attach the documents the text channel could not represent — the ones
    // whose OCR failed or came back near-empty — so vision gets a look at them.
    // Anything not attached here is still present in the source text above, so
    // every uploaded document reaches the model through one channel or the
    // other. The old `documentFiles.slice(0, 2)` sent the first two regardless
    // of whether they needed it, and silently ignored documents 3..10.
    const inlineCandidates = [
      ...(Array.isArray(priorityFiles) ? priorityFiles : []),
      ...(Array.isArray(documentFiles) ? documentFiles : []),
    ];

    const seenPaths = new Set();
    let inlineBudget = INLINE_BUDGET_BYTES;
    let inlineCount = 0;

    for (const file of inlineCandidates) {
      if (inlineCount >= INLINE_MAX_FILES || inlineBudget <= 0) break;
      if (!file?.path || seenPaths.has(file.path)) continue;
      seenPaths.add(file.path);

      try {
        if (!fs.existsSync(file.path)) continue;

        const ext = path.extname(file.originalname || file.path).toLowerCase();
        let mimeType = file.mimetype;

        if (ext === ".pdf") mimeType = "application/pdf";
        else if (ext === ".png") mimeType = "image/png";
        else if ([".jpg", ".jpeg"].includes(ext)) mimeType = "image/jpeg";
        else if (ext === ".webp") mimeType = "image/webp";

        // Only formats Gemini accepts inline. DOCX and TXT are text-extracted
        // upstream and already sit in the source text.
        if (!mimeType || !(mimeType.startsWith("image/") || mimeType === "application/pdf")) {
          continue;
        }

        const fileBuffer = fs.readFileSync(file.path);
        const encodedSize = Math.ceil(fileBuffer.length / 3) * 4;
        if (encodedSize > inlineBudget) continue;

        parts.push({
          inlineData: { mimeType, data: fileBuffer.toString("base64") },
        });
        inlineBudget -= encodedSize;
        inlineCount += 1;
      } catch (e) {
        console.warn("Could not attach inline document file to Gemini request:", e.message);
      }
    }

    parts.push({ text: sourceText });
    parts.push({ text: prompt });

    const { text: raw, error } = await gemini.generate(parts, { label: "smart-case:extract" });

    if (!raw) {
      console.warn("[aiSmartIntakeService] Gemini API unavailable or rate-limited. Using intelligent fallback extraction:", error);
      return this._fallbackExtraction({ ocrText, voiceTranscript, typedDescription, documentMetadata });
    }

    const parsed = this._parseJson(raw);
    return this._normalise(parsed);
  }

  _fallbackExtraction({ ocrText, voiceTranscript, typedDescription, documentMetadata }) {
    const combinedText = [typedDescription, voiceTranscript, ocrText].filter(Boolean).join("\n\n").trim();
    
    const resolvedCat = taxonomy.resolveCategory(combinedText, "");
    
    const firstLine = typedDescription?.split("\n")[0] || ocrText?.split("\n")[0] || "Legal Case Request";
    const title = firstLine.length > 60 ? `${firstLine.slice(0, 60)}...` : firstLine;
    
    const description = combinedText || "Legal intake request submitted by client.";
    const summary = description.length > 200 ? `${description.slice(0, 200)}...` : description;

    const extracted = {
      title,
      description,
      summary,
      category: resolvedCat.category || null,
      categoryId: resolvedCat.categoryId || null,
      subType: resolvedCat.subType || null,
      urgency: "Medium",
      city: "",
      state: "",
      location: "",
      court: "",
      incidentDate: null,
      opposingParty: "",
      parties: [],
      firNumber: "",
      policeStation: "",
      bailDetails: "",
      claimAmount: null,
      documentType: documentMetadata?.[0]?.name ? `Document (${documentMetadata[0].name})` : "Legal Document",
      isCriminalLike: false,
      confidence: {},
      needsReview: [],
    };

    return {
      extracted,
      warnings: ["AI API quota reached or unavailable; pre-filled case details using local text extraction."],
    };
  }

  /** Strips accidental markdown fences and parses; throws with context. */
  _parseJson(raw) {
    const cleaned = raw
      .replace(/```json/gi, "")
      .replace(/```/g, "")
      .trim();

    try {
      return JSON.parse(cleaned);
    } catch (e) {
      // Last resort: grab the outermost object if the model wrapped it in prose.
      const first = cleaned.indexOf("{");
      const last = cleaned.lastIndexOf("}");
      if (first !== -1 && last > first) {
        try {
          return JSON.parse(cleaned.slice(first, last + 1));
        } catch {
          /* fall through */
        }
      }
      console.error("Could not parse extraction JSON:", cleaned.slice(0, 400));
      throw new Error("The AI returned an unreadable response. Please try again.");
    }
  }

  /**
   * Coerces the model's answer into the exact shapes the form expects, and
   * drops anything that does not belong.
   */
  _normalise(parsed) {
    const warnings = [];

    const str = (v) => {
      if (v === null || v === undefined) return "";
      const s = String(v).trim();
      // Models sometimes emit these instead of a real null.
      if (!s || /^(null|n\/?a|none|unknown|not (specified|available|mentioned))$/i.test(s)) {
        return "";
      }
      return s;
    };

    const date = (v) => {
      const s = str(v);
      if (!s) return null;
      const d = new Date(s);
      if (Number.isNaN(d.getTime())) return null;
      // An incident cannot be in the future; a mis-parsed year is more likely.
      if (d.getTime() > Date.now()) {
        warnings.push("Ignored an incident date in the future.");
        return null;
      }
      return d.toISOString().slice(0, 10);
    };

    const num = (v) => {
      if (v === null || v === undefined || v === "") return null;
      // Match the first number-like token rather than stripping non-digits:
      // stripping left the "." from "Rs." attached to the digits, so
      // "Rs. 50,000" parsed as 0.5. Commas are removed first so Indian
      // grouping ("1,25,000") survives.
      const match = String(v).replace(/,/g, "").match(/\d+(?:\.\d+)?/);
      if (!match) return null;
      const n = Number(match[0]);
      return Number.isFinite(n) && n > 0 ? n : null;
    };

    // Category and sub-type are mapped onto the app's exact strings so the
    // dropdowns can select them; null when nothing credible matched.
    const resolved = taxonomy.resolveCategory(parsed.category, parsed.subType);
    if (str(parsed.category) && !resolved.category) {
      warnings.push(
        `Could not match "${str(parsed.category)}" to a category — please pick one.`
      );
    }

    const allowedUrgency = ["Urgent", "High", "Medium", "Flexible"];
    const urgency = allowedUrgency.find(
      (u) => u.toLowerCase() === str(parsed.urgency).toLowerCase()
    ) || null;

    // FIR / police station / bail only make sense for criminal-like categories.
    // Discard them otherwise so the form does not reveal that field group for,
    // say, a GST notice just because the model volunteered a stray value.
    const criminalLike = resolved.category
      ? taxonomy.isCriminalLike(resolved.category)
      : false;

    // Per-field confidence, clamped to 0-1. A field the model filled but did
    // not score is treated as unscored rather than as certain.
    const rawConfidence =
      parsed.confidence && typeof parsed.confidence === "object" ? parsed.confidence : {};
    const confidence = {};
    for (const [field, value] of Object.entries(rawConfidence)) {
      const score = Number(value);
      if (Number.isFinite(score)) {
        confidence[field] = Math.min(1, Math.max(0, score));
      }
    }

    // Named parties, deduplicated on name. Feeds the "Other Party" field and is
    // shown in full on the review step.
    const parties = [];
    const seenParties = new Set();
    if (Array.isArray(parsed.parties)) {
      for (const entry of parsed.parties) {
        const name = str(entry?.name);
        if (!name) continue;
        const key = name.toLowerCase();
        if (seenParties.has(key)) continue;
        seenParties.add(key);
        parties.push({ name, role: str(entry?.role) });
      }
    }

    const extracted = {
      title: str(parsed.title),
      description: str(parsed.description),
      summary: str(parsed.summary),
      category: resolved.category,
      categoryId: resolved.categoryId,
      subType: resolved.subType,
      urgency,
      city: str(parsed.city),
      state: str(parsed.state),
      location: str(parsed.location),
      court: str(parsed.court),
      incidentDate: date(parsed.incidentDate),
      opposingParty: str(parsed.opposingParty),
      parties,
      firNumber: criminalLike ? str(parsed.firNumber) : "",
      policeStation: criminalLike ? str(parsed.policeStation) : "",
      bailDetails: criminalLike ? str(parsed.bailDetails) : "",
      claimAmount: num(parsed.claimAmount),
      documentType: str(parsed.documentType),
      isCriminalLike: criminalLike,
      confidence,
    };

    // A value the model itself is unsure of must not be pre-filled into a form
    // the client is about to file as a legal case. It is cleared here and
    // named in `needsReview`, so the field shows empty and flagged rather than
    // pre-filled and wrong.
    // Each reviewable field maps to the empty value its consumer expects, so
    // clearing one leaves the exact shape the Post Case form treats as "not
    // extracted" rather than a type it has to guess at.
    const EMPTY_WHEN_UNSURE = {
      title: "",
      description: "",
      city: "",
      state: "",
      location: "",
      court: "",
      opposingParty: "",
      firNumber: "",
      policeStation: "",
      bailDetails: "",
      category: null,
      subType: null,
      urgency: null,
      incidentDate: null,
      claimAmount: null,
    };

    const needsReview = [];
    for (const [field, emptyValue] of Object.entries(EMPTY_WHEN_UNSURE)) {
      const value = extracted[field];
      if (value === null || value === undefined || value === "") continue;

      const score = confidence[field];
      if (score === undefined || score >= CONFIDENCE_FLOOR) continue;

      needsReview.push(field);
      extracted[field] = emptyValue;
      // categoryId is derived from category and must not outlive it.
      if (field === "category") extracted.categoryId = null;
    }
    extracted.needsReview = needsReview;

    return {
      extracted,
      warnings: [
        ...warnings,
        ...(Array.isArray(parsed.unreadableDocumentNotes)
          ? parsed.unreadableDocumentNotes.map(str).filter(Boolean)
          : []),
      ],
    };
  }
}

module.exports = new AiSmartIntakeService();
