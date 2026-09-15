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
 * The category is the exception to the floor above, and deliberately so.
 *
 * Clearing a moderately-confident category leaves the Post Case dropdown empty,
 * which a client reads as the analysis having failed — and unlike a wrong name
 * or a wrong amount, a wrong category costs them one tap to correct and is
 * visible the moment the form opens. So a category scored between this floor
 * and CONFIDENCE_FLOOR is kept AND flagged in `needsReview`, rather than
 * thrown away. Below this, the model is guessing and the dropdown is left
 * alone.
 */
const CATEGORY_CONFIDENCE_FLOOR = 0.35;

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
 * Budget for the "Brief Description of Your Case" field.
 *
 * That input is read by lawyers deciding whether to take the matter on, so it
 * is a synopsis, not a transcript. The extraction used to be told to produce a
 * "factual summary of what happened: parties, amounts, places, dates", which a
 * model reasonably satisfies by restating most of a petition — the form then
 * opened with several hundred words of names, ages, occupations and postal
 * addresses in a field asking for a brief description.
 *
 * TARGET is what the prompt asks for. MAX is the ceiling enforced here: past
 * it the text is condensed by a second model call, and only if that fails is
 * it trimmed — always on a sentence boundary, never mid-word.
 */
const SUMMARY_TARGET_MIN_WORDS = 40;
const SUMMARY_TARGET_MAX_WORDS = 80;
const SUMMARY_MAX_WORDS = 110;
const SUMMARY_MAX_SENTENCES = 5;

/** Ceiling for the read-only synopsis panel. Not a form field, so it is looser. */
const SYNOPSIS_MAX_WORDS = 120;

/**
 * Identifiers that must not survive into a case description.
 *
 * The client's own personal details are already on their account, and the
 * opposing party's are not ours to republish to every lawyer who views the
 * case. The prompt asks the model to leave these out; this is the net under
 * it, because one leaked Aadhaar number is not recoverable by editing the
 * field afterwards.
 *
 * Currency is deliberately not matched: "Rs. 4,50,000" is the substance of a
 * recovery suit, and `claimAmount` carries it as a number besides.
 */
const SENSITIVE_PATTERNS = [
  // Email addresses.
  /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi,
  // Indian mobile numbers, with or without a country code or separators.
  /(?:\+?91[\s-]?)?\b[6-9]\d{4}[\s-]?\d{5}\b/g,
  // Aadhaar: 12 digits, usually grouped in fours.
  /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g,
  // PAN.
  /\b[A-Z]{5}\d{4}[A-Z]\b/g,
  // Bank account numbers: 9+ unbroken digits.
  /\b\d{9,18}\b/g,
];

/**
 * States and union territories, matched when reducing a postal address to the
 * city the case belongs to. In an Indian address the state sits between the
 * city and the PIN code, so it is the segment most often mistaken for one.
 */
const INDIAN_STATES = new Set(
  [
    "andhra pradesh", "arunachal pradesh", "assam", "bihar", "chhattisgarh",
    "goa", "gujarat", "haryana", "himachal pradesh", "jharkhand", "karnataka",
    "kerala", "madhya pradesh", "maharashtra", "manipur", "meghalaya",
    "mizoram", "nagaland", "odisha", "orissa", "punjab", "rajasthan", "sikkim",
    "tamil nadu", "telangana", "tripura", "uttar pradesh", "uttarakhand",
    "west bengal", "andaman and nicobar islands", "chandigarh",
    "dadra and nagar haveli and daman and diu", "delhi", "new delhi",
    "jammu and kashmir", "ladakh", "lakshadweep", "puducherry", "pondicherry",
    "india",
  ]
);

/**
 * Address furniture. A segment that is only one of these — or that carries a
 * house/flat/door number — names a building, not a city.
 */
const ADDRESS_NOISE = /^(?:flat|plot|door|house|h\.?no|d\.?no|shop|room|floor|block|survey|khasra|apartment|apartments|residency|towers?|colony|nagar|road|rd|street|st|lane|cross|main|marg|sector|phase|near|opp|opposite|behind|beside|above|c\/o|p\.?o|post|village|taluk|taluka|mandal|tehsil|pin|pincode|zip)\b/i;

/**
 * The label half of a "Label value" line from a document header.
 *
 * Matching the label is not enough on its own — "Respondent Vikram Sharma" is
 * a field and "Respondent failed to pay" is a sentence. `_dropFieldDumpLines`
 * therefore checks what follows the label separately, and case-sensitively,
 * which is why the case-insensitive flag here cannot cover both halves.
 */
const FIELD_LABEL_PREFIX =
  /^(?:petitioner|respondent|complainant|accused|applicant|defendant|plaintiff|appellant|address|age|occupation|profession|phone|mobile|contact|email|name|father|mother|husband|wife|nationality|gender|residing)\b\s*[:\-]?\s*/i;

/**
 * Native structured output for the extraction call.
 *
 * Gemini honours this schema itself, so the answer is already a JSON object of
 * the right shape rather than prose we hope parses. The prompt-only approach it
 * replaces produced markdown fences, leading commentary and occasional prose
 * around the object — `_parseJson` still handles all of that, because the
 * fallback path below runs without the schema when a model rejects it.
 *
 * Every scalar is a STRING, including the date and the claim amount. The
 * schema's job is to fix the SHAPE; `_normalise` fixes the types, and it
 * already coerces "", "null", "N/A" and "Rs. 50,000" correctly. Declaring
 * numbers here instead would make a model that has nothing to report choose
 * between inventing a figure and breaking the schema.
 */
const EXTRACTION_SCHEMA = {
  type: "OBJECT",
  properties: {
    title: { type: "STRING" },
    description: { type: "STRING" },
    summary: { type: "STRING" },
    category: { type: "STRING" },
    subType: { type: "STRING" },
    urgency: { type: "STRING" },
    city: { type: "STRING" },
    state: { type: "STRING" },
    location: { type: "STRING" },
    court: { type: "STRING" },
    incidentDate: { type: "STRING" },
    opposingParty: { type: "STRING" },
    parties: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: { name: { type: "STRING" }, role: { type: "STRING" } },
        required: ["name"],
      },
    },
    firNumber: { type: "STRING" },
    policeStation: { type: "STRING" },
    bailDetails: { type: "STRING" },
    claimAmount: { type: "STRING" },
    documentType: { type: "STRING" },
    confidence: {
      type: "OBJECT",
      properties: Object.fromEntries(
        [
          "title", "description", "category", "subType", "city", "state",
          "location", "court", "incidentDate", "opposingParty", "firNumber",
          "policeStation", "bailDetails", "claimAmount", "urgency",
        ].map((field) => [field, { type: "NUMBER" }])
      ),
    },
    unreadableDocumentNotes: { type: "ARRAY", items: { type: "STRING" } },
  },
  required: ["title", "description", "summary", "category", "city", "court", "confidence"],
  propertyOrdering: [
    "title", "description", "summary", "category", "subType", "urgency",
    "city", "state", "location", "court", "incidentDate", "opposingParty",
    "parties", "firNumber", "policeStation", "bailDetails", "claimAmount",
    "documentType", "confidence", "unreadableDocumentNotes",
  ],
};

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
    // Which sources actually carry content. The model is told this explicitly,
    // because "None provided." buried inside a section header is easy for it to
    // skim past — and a model that thinks it has a voice note when it does not
    // will invent what the client said.
    const available = {
      document: Boolean((ocrText || "").trim()) || (documentFiles || []).length > 0,
      documentText: Boolean((ocrText || "").trim()),
      voice: Boolean((voiceTranscript || "").trim()),
      notes: Boolean((typedDescription || "").trim()),
    };

    const presentSources = [
      available.document ? "DOCUMENT" : null,
      available.voice ? "VOICE NOTE" : null,
      available.notes ? "WRITTEN NOTES" : null,
    ].filter(Boolean);

    const sourceText = `
=== SOURCES AVAILABLE FOR THIS CASE ===
${presentSources.length ? presentSources.join(" + ") : "NONE"}
Analyse every source listed above. Do not ignore one because another is longer
or more formal. Do not refer to a source that is not listed.

=== UPLOADED DOCUMENT TEXT ${available.documentText ? "" : "(none extracted — read the attached file(s) directly if any are attached)"} ===
${ocrText || "No document text could be extracted."}

=== VOICE NOTE TRANSCRIPT ${available.voice ? "" : "(the client did not record one)"} ===
${voiceTranscript || "None provided."}

=== ADDITIONAL WRITTEN NOTES ${available.notes ? "" : "(the client did not write any)"} ===
${typedDescription || "None provided."}

=== ATTACHED DOCUMENT METADATA ===
${JSON.stringify(documentMetadata || [], null, 2)}
`;

    const prompt = `You are a legal document analysis assistant for an Indian lawyer-marketplace app.

READ AND UNDERSTAND the client's documents, voice transcript and written notes,
then fill the fields below. You are not transcribing the documents — you are
working out what the matter actually is and reporting it.

CRITICAL RULES:
1. Use "" (an empty string) for any field the sources do not actually establish.
   NEVER invent, infer or fill a plausible-looking placeholder. An empty string
   is correct and expected. For "parties", use an empty array.
2. "category" MUST be copied EXACTLY from the list below, character for
   character, and "subType" MUST be one of that category's own sub-types,
   copied exactly. See the classification section below — this is the field
   the form depends on most.
3. Dates must be ISO 8601 (YYYY-MM-DD). If only a month/year is known, use the
   first day of that month. If no date is stated, "".
── COMBINING THE SOURCES ──────────────────────────────────────────────────────
You may be given a document, a voice note, written notes, or any combination.
Produce ONE unified analysis of ONE matter from everything you were given.

What each source is for:
  DOCUMENT      — the factual and legal record: parties, agreements, amounts,
                  dates, the court and the jurisdiction.
  VOICE NOTE    — the client explaining, in their own words, what is actually
                  wrong now. This is usually where the real grievance is.
  WRITTEN NOTES — clarification the client typed.

The document is the primary source for legal facts. The voice note is the
primary source for what the client wants help with. Both go into the analysis:
  - A problem the client raises in the voice note that the document does not
    cover IS part of this case. Include it.
    Example — document: a property sale agreement and payment schedule; voice:
    "the buyer has stopped responding and has not paid the balance". The case is
    the non-payment, and the agreement is its background. Report both.
  - A fact stated in the document that the client does not mention is still a
    fact of the case.

When the sources CONFLICT, resolve in this order and do not simply pick one:
  1. An explicit legal fact recorded in the document (a named party, a signed
     amount, a filed date);
  2. Court or jurisdiction stated in the document;
  3. A fact the client states plainly in the voice note or written notes;
  4. Supporting or contextual detail from any source.
If a conflict cannot be resolved, keep the reliable part, leave the disputed
field empty rather than guessing, and score it low in "confidence".

An uploaded file may be unrelated to the matter (a resume, an ID scan, a random
photo). If the document plainly does not concern the problem the client
describes, base the case on what the client said and record what the file
appears to be in "documentType" only — do not merge two unrelated matters.

── LANGUAGE ───────────────────────────────────────────────────────────────────
The voice note may be in English, Telugu, Hindi, or a mix ("Ma husband nannu
abuse chestunnadu and nenu divorce file cheyyali"), and it may contain speech
recognition errors. Understand what the client MEANT and write every output
field in clear English. Never copy the transcript into a field, never reproduce
a mis-transcribed phrase, and never translate word for word into something that
does not read as English. If a passage is too garbled to be sure of, ignore that
passage rather than guessing at it.

── "description": THE BRIEF CASE SUMMARY ──────────────────────────────────────
This goes straight into a form field labelled "Brief Description of Your Case",
which a lawyer reads to decide whether to take the matter on. It is the single
most important field you produce.

Write ${SUMMARY_TARGET_MIN_WORDS}-${SUMMARY_TARGET_MAX_WORDS} words, in 3-4 complete sentences, answering:
  a) who is involved (by name and role, e.g. "Ananya Rao" against "Vikram Sharma");
  b) what happened, in substance;
  c) what the main legal dispute or issue is;
  d) what relief or outcome is sought, when the sources identify one.

Write it as flowing prose in the third person. Never as a list, never as
"Field: value" lines, never as headings.

It MUST NOT contain: residential or postal addresses, ages, occupations, phone
numbers, email addresses, Aadhaar/PAN/passport/voter-ID numbers, bank or account
numbers, a page-by-page chronology, verbatim passages from the document, a
recital of every person named, or the text of a legal notice. Keep a case or FIR
number out of it unless the matter cannot be understood without it — those have
their own fields.

Do NOT copy sentences out of the document. Understand it, then write the summary
in your own words.

GOOD (this is the standard to hit):
"Ananya Rao has filed a dispute against Vikram Sharma over a payment disagreement
arising from a software services agreement. The petitioner states that the agreed
consideration was never paid despite her completing the contracted work. The
matter concerns recovery of the outstanding amount together with contractual
remedies."

BAD (never produce anything shaped like this):
"Petitioner: Ananya Rao. Age/Occupation: 32/Software Engineer. Address: Flat 302,
Sunrise Residency, Madhapur, Hyderabad. Respondent: Vikram Sharma. Age: 35..."

── "city": THE RELEVANT LEGAL LOCATION ────────────────────────────────────────
A CITY OR TOWN NAME ONLY — "Hyderabad", "Visakhapatnam". Never a full address,
never a locality-plus-city string, never a state, never a PIN code. From
"Flat 302, Sunrise Residency, Madhapur, Hyderabad, Telangana - 500081" the
correct answer is exactly "Hyderabad".

Do NOT take the first address you encounter. Work out which city the matter
legally belongs to, in this order of priority:
  1. The city of the court or jurisdiction the documents name;
  2. The place where the dispute arose — where the cause of action occurred;
  3. The location of the property, business or event the case is about;
  4. The petitioner's or complainant's city;
  5. The city of whichever party is the primary one.
Stop at the highest rung the documents actually support. If the documents name
several cities and none of the rungs above settles it, pick the one the matter
most clearly centres on and score "city" low in "confidence". If no city can be
established at all, return "" — never guess one.

── "court" ────────────────────────────────────────────────────────────────────
Only when a court, tribunal, forum or commission is EXPLICITLY named or its
jurisdiction is explicitly stated. Give the name with its place, as written:
"District Court, Visakhapatnam", "XIV Additional Chief Metropolitan Magistrate,
Hyderabad", "National Company Law Tribunal, Bengaluru". Do NOT derive a court
from the city, and do NOT propose the court the matter ought to be filed in.
If no court is named, return "".

── CHOOSING THE CATEGORY ──────────────────────────────────────────────────────
Classify on the PRIMARY LEGAL ISSUE — what the client actually needs a lawyer
for — not on whichever word appears most often. A divorce petition that spends
most of its pages dividing property is a Family & Divorce matter, not a
Property & Land one. A cheque handed over under an employment settlement is
judged by which dispute the client is bringing.

Classify whenever the sources support it. The client sees an empty dropdown as
the analysis having failed, so "" is only correct when you genuinely cannot tell
what kind of matter this is — not when you are choosing between two plausible
categories. In that case pick the better fit and score it honestly in
"confidence"; a category at 0.6 is useful to the client, an empty one is not.

Pick the category first, then the sub-type from that category's own list. If the
category is clear but no sub-type fits well, give the category and leave
"subType" empty — never move to a different category just to reach a sub-type
you prefer.

Worked examples, using the exact strings below:
  divorce, domestic violence, maintenance, custody   -> "Family & Divorce"
  land boundary, builder delay, RERA, partition      -> "Property & Land"
  unpaid dues, contract breach, money recovery       -> "Civil Cases"
  FIR, theft, assault, cheating                      -> "Criminal Law"
  UPI fraud, online scam, hacked account             -> "Cyber Crime"
  salary unpaid, wrongful termination, harassment    -> "Employment & Labour"
  defective product, refund refused                  -> "Consumer Complaints"
  cheque bounce, loan or EMI dispute, bank fraud     -> "Banking & Financial"
  company, partnership, trademark disputes           -> "Business & Corporate"
  road accident compensation or insurance claim      -> "Motor Accident Claims"

ALLOWED CATEGORIES AND SUB-TYPES — copy one of these strings exactly:
${taxonomy.promptTaxonomy()}

5. "confidence" must carry an honest 0-1 score for every field you filled.
   Score how certain you are that the value is correct FOR THIS CLIENT'S
   MATTER — not how clearly you read the characters. A name read perfectly
   off a document that may belong to a different matter is LOW confidence.
   Score 0 for a field you left empty.

FIELD NOTES:
- "title": short factual case title, max 12 words. This is the matter's main
  issue in one line ("Recovery of unpaid software services fee").
- "summary": 2-3 neutral sentences describing what you understood, shown to the
  client read-only so they can check the analysis. Same privacy rules as
  "description".
- "state": state or union territory name only.
- "location": the fuller locality the documents state, if any ("Madhapur,
  Hyderabad"). Kept separately so "city" can stay a clean city name; it is NOT
  a place to put a full postal address.
- "urgency": one of Urgent, High, Medium, Flexible, or "".
- "opposingParty": the single main opposing party's name.
- "parties": everyone the documents identify, each with their role
  (Complainant, Accused, Landlord, Employer, Bank, Petitioner, Respondent...).
- "firNumber" / "policeStation" / "bailDetails": criminal, cyber and accident
  matters only. "" otherwise.
- "claimAmount": the sum claimed or disputed, digits only, in INR. "" if none.
- "documentType": what the upload appears to be (FIR, Sale Deed, Legal Notice,
  Agreement, Bank Memo, Medical Report...).
- "incidentDate": when the incident happened, NOT the filing or notice date.
- "unreadableDocumentNotes": short notes about pages you could not read. Empty
  array if none.

Return ONLY the JSON object described by the response schema.`;

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

    // Native structured output first: the model is constrained to the schema
    // rather than asked nicely for JSON in the prompt, which is what removes
    // the fences-and-prose class of parse failure at the source.
    let { text: raw, error } = await gemini.generate(parts, {
      label: "smart-case:extract",
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: EXTRACTION_SCHEMA,
        // Extraction is a reading task, not a creative one. A low temperature
        // is what stops the model smoothing over a gap with a plausible city.
        temperature: 0.2,
      },
    });

    // A model that does not support responseSchema answers 400, which
    // `generate` reports as fatal without trying the rest of the list. One
    // plain retry keeps this working on every model in DEFAULT_MODELS: the
    // prompt already specifies the same object, and `_parseJson` still copes
    // with fences and stray prose.
    if (!raw) {
      console.warn("[aiSmartIntakeService] Structured extraction call failed; retrying without a response schema:", error);
      ({ text: raw, error } = await gemini.generate(parts, {
        label: "smart-case:extract-plain",
        passes: 1,
      }));
    }

    if (!raw) {
      console.warn("[aiSmartIntakeService] Gemini API unavailable or rate-limited. Using intelligent fallback extraction:", error);
      return this._fallbackExtraction({ ocrText, voiceTranscript, typedDescription, documentMetadata });
    }

    const parsed = this._parseJson(raw);
    const result = this._normalise(parsed);

    // Length and privacy control runs after normalisation so it operates on the
    // final strings, and is awaited here because condensing an over-long
    // summary costs a second model call.
    result.warnings.push(...(await this._enforceSummaryQuality(result.extracted)));

    return result;
  }

  _fallbackExtraction({ ocrText, voiceTranscript, typedDescription, documentMetadata }) {
    const combinedText = [typedDescription, voiceTranscript, ocrText].filter(Boolean).join("\n\n").trim();
    
    // `resolveCategory` matches category NAMES; handed free prose it latches
    // onto incidental words ("someone hacked my UPI and took money" came back
    // as Civil Cases / Money Recovery). Keyword classification is the honest
    // tool for raw text, and it returns null rather than reaching.
    const resolvedCat = taxonomy.classifyByKeywords(combinedText) || {
      category: null,
      categoryId: null,
      subType: null,
    };
    
    const firstLine = typedDescription?.split("\n")[0] || ocrText?.split("\n")[0] || "Legal Case Request";
    const title = firstLine.length > 60 ? `${firstLine.slice(0, 60)}...` : firstLine;
    
    // No model answered, so there is no understanding of the document to work
    // from - only the raw text. The client's own words are used when they wrote
    // any, because those are already a description of their problem; document
    // OCR is not, and dumping it into the form is the exact failure this whole
    // path exists to avoid. Both are scrubbed and cut on sentence boundaries.
    const ownWords = [typedDescription, voiceTranscript].filter(Boolean).join("\n\n").trim();
    const description = this._trimToSentences(
      this._scrubSensitive(ownWords || combinedText),
      SUMMARY_TARGET_MAX_WORDS
    );
    const summary = this._trimToSentences(description, SUMMARY_TARGET_MIN_WORDS);

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
      // Nothing here came from an analysis, so everything the form pre-fills
      // is put to the client rather than presented as extracted.
      needsReview: [resolvedCat.category ? "category" : null, "description"].filter(Boolean),
    };

    return {
      extracted,
      warnings: [
        "The document analysis service was unavailable, so your case details could not be extracted from the documents. Please check the form and fill in anything missing.",
      ],
    };
  }

  // ---------------------------------------------------------------------------
  // Summary quality control
  // ---------------------------------------------------------------------------

  /**
   * Keeps the brief description brief, and keeps personal identifiers out of
   * it. Mutates `extracted` and returns any warnings the client should see.
   *
   * The order matters. Scrubbing comes first so a condensation is never asked
   * to reproduce an identifier it was handed. Condensing comes second because
   * a model rewriting to a word budget produces whole sentences; trimming is
   * the last resort and only ever cuts between sentences, so the field never
   * ends mid-thought. Nothing here is a fixed character cut - that was the
   * approach this replaces and it truncated summaries into fragments.
   */
  async _enforceSummaryQuality(extracted) {
    const warnings = [];

    extracted.summary = this._trimToSentences(
      this._scrubSensitive(extracted.summary),
      SYNOPSIS_MAX_WORDS
    );

    const scrubbed = this._scrubSensitive(extracted.description);
    if (!scrubbed) {
      extracted.description = "";
      return warnings;
    }

    if (
      this._wordCount(scrubbed) <= SUMMARY_MAX_WORDS &&
      this._splitSentences(scrubbed).length <= SUMMARY_MAX_SENTENCES
    ) {
      extracted.description = scrubbed;
      return warnings;
    }

    console.warn(
      `[aiSmartIntakeService] Description came back at ${this._wordCount(scrubbed)} words; condensing.`
    );

    const condensed = await this._condense(scrubbed);
    if (condensed && this._wordCount(condensed) <= SUMMARY_MAX_WORDS) {
      extracted.description = condensed;
      return warnings;
    }

    // Last resort, reached only when the model returned a dump AND the rewrite
    // also failed. Field-dump lines are dropped before trimming, because
    // keeping the first N sentences of a dump keeps exactly the "Petitioner:
    // ... Age: ... Address: ..." header this whole path exists to prevent.
    extracted.description = this._trimToSentences(
      this._dropFieldDumpLines(scrubbed),
      SUMMARY_TARGET_MAX_WORDS
    );
    warnings.push(
      "Your documents were long, so the description was shortened to the key points. Please check it reads correctly and add anything important."
    );
    return warnings;
  }

  /**
   * Asks the model to rewrite an over-long description to the field's budget.
   *
   * One pass and a short timeout: this runs inside the extraction step's own
   * timeout, and a summary that is merely too long is still usable, so there
   * is nothing here worth making the client wait on. Returns null on any
   * failure and the caller trims instead.
   */
  async _condense(text) {
    const { text: raw } = await gemini.generate(
      [
        {
          text: `Rewrite the case description below as ${SUMMARY_TARGET_MIN_WORDS}-${SUMMARY_TARGET_MAX_WORDS} words in 3-4 complete sentences.

Keep: who is involved, what happened, the main legal dispute, and the relief sought.
Remove: addresses, ages, occupations, phone numbers, email addresses, ID and account numbers, dates that are not essential, and any person not central to the dispute.
Write flowing third-person prose. Do not use lists, headings or "Field: value" lines.
Do not add anything that is not already in the text below.

Reply with the rewritten description and nothing else.

---
${text}`,
        },
      ],
      { label: "smart-case:condense", passes: 1, timeoutMs: 25000 }
    );

    if (!raw) return null;

    // The instruction is "reply with the description and nothing else", but a
    // model that prefixes "Here is the rewritten description:" should not cost
    // us the rewrite.
    const cleaned = raw
      .replace(/^```[a-z]*\s*/i, "")
      .replace(/```$/, "")
      .replace(/^(?:here(?:'s| is)[^\n:]*:|rewritten description:)\s*/i, "")
      .trim();

    return cleaned || null;
  }

  /**
   * Removes personal identifiers, leaving readable prose behind.
   *
   * The sentence is repaired after each removal - a dangling "reachable at ,"
   * reads worse than the number did - and a sentence left with no words at all
   * is dropped rather than kept as stray punctuation.
   */
  _scrubSensitive(text) {
    if (!text) return "";

    let out = String(text);
    for (const pattern of SENSITIVE_PATTERNS) {
      out = out.replace(pattern, " ");
    }

    return out
      .replace(/\s{2,}/g, " ")
      .replace(/\s+([,.;:])/g, "$1")
      .replace(/([,;:])\s*(?=[.;,])/g, "")
      .replace(/\(\s*\)/g, "")
      .split(/(?<=[.!?])\s+/)
      .filter((sentence) => /[A-Za-z]{3}/.test(sentence))
      .join(" ")
      .trim();
  }

  /**
   * Drops the "Label: value" lines out of a document dump, leaving the
   * sentences that actually say something about the matter.
   *
   * Conservative on purpose: it runs only on the last-resort path, and it
   * returns the input untouched if the filter would leave nothing, so a
   * description written in genuinely short sentences is never emptied.
   */
  _dropFieldDumpLines(text) {
    const sentences = this._splitSentences(text);
    if (sentences.length < 3) return text;

    const kept = sentences.filter((sentence) => {
      const words = this._wordCount(sentence);
      // "Age 32.", "Phone.", "Occupation Software Engineer." — a label and its
      // value, not a statement.
      if (words <= 6) return false;
      // "Address: Flat 302, Sunrise Residency, Madhapur." — longer, but still a
      // labelled field rather than prose.
      if (words <= 14 && /^[A-Z][A-Za-z .\/]{0,28}:\s/.test(sentence)) return false;
      // The same line with the colon lost to OCR. A label word followed by a
      // capital or a digit is a value; followed by a lowercase word it is a
      // sentence — which is what keeps "Respondent failed to pay the agreed
      // consideration" while dropping "Respondent Vikram Sharma".
      if (words <= 14) {
        const label = sentence.match(FIELD_LABEL_PREFIX);
        if (label && /^[A-Z0-9]/.test(sentence.slice(label[0].length))) return false;
      }
      return true;
    });

    return kept.length ? kept.join(" ") : text;
  }

  _wordCount(text) {
    if (!text) return 0;
    return text.trim().split(/\s+/).filter(Boolean).length;
  }

  /**
   * Splits on sentence-ending punctuation, keeping the punctuation attached.
   *
   * Abbreviations that end in a full stop ("Rs.", "Pvt.", "Ltd.", "No.",
   * "vs.") are not sentence ends, and splitting on them produced one-word
   * "sentences" that the trimmer then counted against its budget.
   */
  _splitSentences(text) {
    if (!text) return [];
    const ABBREVIATION =
      /\b(Rs|Pvt|Ltd|No|Nos|Sec|Art|vs|v|Mr|Mrs|Ms|Dr|Smt|Sri|Hon|Jr|Sr|St|Approx|Inc|Co)\.\s/gi;
    const GUARD = "<!dot!>";

    return text
      .replace(ABBREVIATION, `$1${GUARD}`)
      .split(/(?<=[.!?])\s+/)
      .map((sentence) => sentence.split(GUARD).join(". ").trim())
      .filter(Boolean);
  }

  /**
   * Keeps whole sentences up to a word budget.
   *
   * Always returns at least the first sentence, even when that one sentence is
   * over budget: a complete sentence that runs long is readable, and half a
   * sentence is not. This is the last resort in `_enforceSummaryQuality`, not
   * the primary mechanism - the prompt and the condensation pass are.
   */
  _trimToSentences(text, maxWords) {
    if (!text) return "";
    if (this._wordCount(text) <= maxWords) return text.trim();

    const sentences = this._splitSentences(text);
    if (sentences.length <= 1) return text.trim();

    const kept = [];
    let words = 0;
    for (const sentence of sentences) {
      const length = this._wordCount(sentence);
      if (kept.length > 0 && words + length > maxWords) break;
      kept.push(sentence);
      words += length;
    }

    return (kept.length ? kept : [sentences[0]]).join(" ").trim();
  }

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  /**
   * Reduces whatever the model put in `city` to a city name, and recovers one
   * from `location` when `city` came back empty.
   *
   * The prompt asks for a bare city name and mostly gets one, but "City /
   * Location" is a required field on a form the client is about to file, so a
   * model that answers "Madhapur, Hyderabad, Telangana - 500081" should not
   * cost them a clean value. Returns "" when nothing in the input is
   * recognisable as a city - an empty required field the client fills in is
   * the correct outcome, and much better than a confident wrong one.
   */
  _cityFrom(city, location) {
    const direct = this._reduceToCity(city);
    if (direct) return direct;
    return this._reduceToCity(location);
  }

  /**
   * Takes the city segment out of an address.
   *
   * Indian addresses run smallest-to-largest - building, locality, city,
   * state, PIN - so the city is the last segment that is not the state and not
   * a PIN code. Segments are dropped rather than scored: a house number, a
   * PIN, a state name and a street are each disqualifying on their own, and
   * what survives at the end of the list is the city.
   */
  _reduceToCity(value) {
    const raw = String(value ?? "").trim();
    if (!raw) return "";

    const segments = raw
      // "Hyderabad - 500081" attaches a PIN with a dash rather than a comma.
      .replace(/[-–—]\s*\d{6}\b/g, ",")
      .split(/[,\n]/)
      .map((segment) =>
        segment
          .replace(/\b(?:pin|pincode|zip)\b[:\s-]*/gi, "")
          // A PIN written straight after the city ("Hyderabad 500034") shares a
          // segment with it. Dropping the whole segment for containing a digit
          // would throw the city away along with the PIN.
          .replace(/\b\d{6}\b/g, "")
          .trim()
      )
      .filter(Boolean);

    const candidates = segments.filter((segment) => {
      if (/\d/.test(segment)) return false;              // house numbers, PINs
      if (ADDRESS_NOISE.test(segment)) return false;     // "Flat", "Near", "Road"
      if (INDIAN_STATES.has(segment.toLowerCase())) return false;
      const words = segment.split(/\s+/);
      if (words.length > 4) return false;                // a phrase, not a place
      return /[A-Za-z]{3}/.test(segment);
    });

    if (candidates.length === 0) return "";

    // The last surviving segment is the city; anything after it was a state or
    // a PIN and has already been dropped.
    return candidates[candidates.length - 1].replace(/\s{2,}/g, " ").trim();
  }

  /**
   * Keeps a court value to the court itself.
   *
   * Accepts only a value that names a forum, so a model that answers with a
   * bare city - the one thing the prompt tells it not to do, because the app
   * must never imply a court the documents did not name - leaves the optional
   * field empty instead of putting "Hyderabad" under "Preferred Court
   * Location".
   */
  _cleanCourt(value) {
    const raw = String(value ?? "").trim().replace(/\s{2,}/g, " ");
    if (!raw) return "";

    const namesAForum =
      /\b(court|tribunal|forum|commission|magistrate|judge|bench|authority|adalat|nyayalaya|nclt|drt|ncdrc|sdrc|cat|itat|appellate)\b/i;

    return namesAForum.test(raw) ? raw : "";
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
    // dropdowns can select them.
    //
    // Three passes, in decreasing order of trust:
    //   1. the model's answer, normalised onto the real taxonomy;
    //   2. failing that, deterministic keywords over what the model itself
    //      wrote about the case;
    //   3. failing that, nothing — the dropdown is left for the client.
    // An empty dropdown reads to a client as a failed analysis, so pass 2 is
    // what stops one unmatched string costing them the classification
    // entirely. Anything it produces is flagged for review below.
    let resolved = taxonomy.resolveCategory(parsed.category, parsed.subType);
    let categoryFromKeywords = false;

    if (!resolved.category) {
      const fromKeywords = taxonomy.classifyByKeywords(
        [str(parsed.category), str(parsed.title), str(parsed.description), str(parsed.summary)]
          .filter(Boolean)
          .join(" ")
      );
      if (fromKeywords) {
        resolved = {
          category: fromKeywords.category,
          categoryId: fromKeywords.categoryId,
          subType: null,
        };
        categoryFromKeywords = true;
      } else if (str(parsed.category)) {
        warnings.push(
          `Could not match "${str(parsed.category)}" to a category — please pick one.`
        );
      }
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

    // "City / Location" takes a city, not an address. The model is asked for a
    // bare city name and usually gives one; when it answers with the address
    // it read off the document, the city is taken out of it here rather than
    // filed as-is. `location` keeps the fuller locality for the record.
    const location = str(parsed.location);
    const city = this._cityFrom(str(parsed.city), location);

    // A court is only pre-filled when the documents named one. `_cleanCourt`
    // drops a value that is merely a place, because "Preferred Court Location:
    // Hyderabad" reads as a court the document never mentioned.
    const court = this._cleanCourt(str(parsed.court));

    const extracted = {
      title: str(parsed.title),
      description: str(parsed.description),
      summary: str(parsed.summary),
      category: resolved.category,
      categoryId: resolved.categoryId,
      subType: resolved.subType,
      urgency,
      city,
      state: str(parsed.state),
      location,
      court,
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

      // Category and sub-type are kept through the middle band and only
      // flagged — see CATEGORY_CONFIDENCE_FLOOR.
      const isCategoryField = field === "category" || field === "subType";
      if (isCategoryField && score >= CATEGORY_CONFIDENCE_FLOOR) {
        needsReview.push(field);
        continue;
      }

      needsReview.push(field);
      extracted[field] = emptyValue;
      // categoryId is derived from category and must not outlive it.
      if (field === "category") {
        extracted.categoryId = null;
        // A sub-type cannot belong to a category that was just cleared.
        extracted.subType = null;
      }
    }
    // A category nobody's judgement produced — only our keyword table — is
    // always put to the client, whatever score the model reported for the
    // string it originally answered with.
    if (categoryFromKeywords && extracted.category && !needsReview.includes("category")) {
      needsReview.push("category");
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
