const Lawyer = require("../../models/Lawyer");
const User = require("../../models/User");
const Case = require("../../models/Case");
const gemini = require("./geminiClient");

class AiSmartIntakeService {
  /**
   * Main AI Smart Case Analysis Engine using Gemini Pro
   */
  async analyzeCaseIntake({ ocrText, voiceTranscript, documentMetadata, clientId }) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error("GEMINI_API_KEY is not configured.");
    }

    const combinedText = `
=== VOICE TRANSCRIPT ===
${voiceTranscript || "No voice recording provided."}

=== EXTRACTED DOCUMENT OCR TEXT ===
${ocrText || "No document text extracted."}

=== ATTACHED DOCUMENTS METADATA ===
${JSON.stringify(documentMetadata || [], null, 2)}
`;

    const prompt = `You are an expert AI Legal Intake System for Indian Legal Applications. 
Analyze the user's provided voice transcript and extracted legal document text.
Extract and generate a complete legal case intake profile.

IMPORTANT INSTRUCTION: You MUST return strictly a SINGLE VALID JSON OBJECT matching the following JSON schema. Do NOT include markdown codeblocks (do not surround with \`\`\`json or \`\`\`), do NOT output introductory or concluding text. Return raw valid JSON only.

JSON SCHEMA:
{
  "caseTitle": "Concise, professional legal title for the case (max 10 words)",
  "caseDescription": "Comprehensive, factual legal description summarizing the incident, parties involved, financial amounts, locations, and legal grievances.",
  "category": "One of: Property Law, Criminal Law, Family Law, Labour & Employment, Civil Law, Consumer Protection, Cyber Law, Rental & Tenancy, Motor Vehicle Accidents, Cheque Bounce & Finance, Documentation, General Legal",
  "priority": "High | Medium | Urgent | Flexible",
  "documentType": "One of: FIR, Agreement, Sale Deed, Property Documents, Medical Reports, Court Orders, Affidavits, Cheque, Bank Memo, Legal Notice, Employment Contract, Consumer Complaint, Rental Agreement, Tax Documents, Unknown",
  "applicableLegalDomain": "e.g., Indian Penal Code / Bharatiya Nyaya Sanhita, Specific Relief Act, Consumer Protection Act, Real Estate Regulation Act (RERA), Negotiable Instruments Act Section 138, etc.",
  "requiredSupportingDocuments": ["Array of recommended supporting documents for this legal issue"],
  "aiConfidenceScore": 88,
  "detectedTimeline": ["Array of chronological dates/events extracted from documents/voice"],
  "lawyerSpecializationRequired": "Specialization needed (e.g., Property Advocate, Criminal Defense Lawyer, Family Court Advocate, Corporate Lawyer)",
  "missingInformation": ["List any key missing details e.g., Date of incident, Notice delivery proof, Claim amount, Property survey number"],
  "followUpQuestions": ["Intelligent, specific follow-up questions to ask the user if key details are missing"],
  "fraudFlags": ["Any detected issues e.g. Unclear signature, Missing bank memo stamp, Unreadable page"]
}`;

    const { text: rawAiResponse, error: aiError } = await gemini.generate(
      [{ text: combinedText }, { text: prompt }],
      { label: "smart-case:analyze" }
    );

    if (!rawAiResponse) {
      throw new Error(`Gemini AI analysis failed: ${aiError}`);
    }

    // Parse JSON cleanly
    const cleanedJson = rawAiResponse
      .replace(/```json/gi, "")
      .replace(/```/g, "")
      .trim();

    let parsedResult;
    try {
      parsedResult = JSON.parse(cleanedJson);
    } catch (e) {
      console.error("Failed to parse Gemini JSON:", rawAiResponse);
      parsedResult = {
        caseTitle: "Legal Intake Request",
        caseDescription: ocrText.substring(0, 300) || voiceTranscript.substring(0, 300) || "Legal consultation required.",
        category: "General Legal",
        priority: "Medium",
        documentType: "Document",
        applicableLegalDomain: "Indian Civil Law",
        requiredSupportingDocuments: ["ID Proof", "Relevant Agreements/Receipts"],
        aiConfidenceScore: 75,
        detectedTimeline: [],
        lawyerSpecializationRequired: "General Advocate",
        missingInformation: ["Detailed incident chronology"],
        followUpQuestions: ["Could you provide more specific dates regarding when this issue occurred?"],
        fraudFlags: [],
      };
    }

    // Calculate Case Readiness Score
    const confidence = parsedResult.aiConfidenceScore || 75;
    const hasCategory = !!parsedResult.category;
    const hasTimeline = parsedResult.detectedTimeline && parsedResult.detectedTimeline.length > 0;
    const missingCount = (parsedResult.missingInformation || []).length;
    
    let readinessScore = Math.round(
      confidence * 0.5 +
      (hasCategory ? 20 : 0) +
      (hasTimeline ? 15 : 5) -
      missingCount * 5
    );
    readinessScore = Math.max(30, Math.min(98, readinessScore));
    parsedResult.readinessScore = readinessScore;

    // Check Duplicate Cases for the same client in MongoDB
    const duplicateCheck = await this.checkDuplicateCases(clientId, parsedResult.caseTitle, parsedResult.caseDescription);

    // Get REAL Lawyers from MongoDB
    const recommendedLawyers = await this.getRealLawyerRecommendations(parsedResult.category, parsedResult.lawyerSpecializationRequired);

    return {
      aiAnalysis: parsedResult,
      duplicateCheck,
      recommendedLawyers,
    };
  }

  /**
   * Search MongoDB for duplicate/similar existing cases owned by the authenticated client
   */
  async checkDuplicateCases(clientId, title, description) {
    if (!clientId) return { isDuplicate: false, similarityScore: 0 };

    try {
      const activeCases = await Case.find({
        client: clientId,
        status: { $in: ["Submitted", "Awaiting Lawyer Acceptance", "In Progress"] },
      }).select("_id title description category createdAt");

      if (!activeCases || activeCases.length === 0) {
        return { isDuplicate: false, similarityScore: 0 };
      }

      const cleanTitle = (title || "").toLowerCase();
      const cleanDesc = (description || "").toLowerCase();

      for (const existingCase of activeCases) {
        const existTitle = (existingCase.title || "").toLowerCase();
        const existDesc = (existingCase.description || "").toLowerCase();

        // Check keyword/token overlap
        const titleTokens = cleanTitle.split(/\s+/).filter((t) => t.length > 3);
        const matchCount = titleTokens.filter((t) => existTitle.includes(t) || existDesc.includes(t)).length;

        if (titleTokens.length > 0 && matchCount / titleTokens.length >= 0.6) {
          return {
            isDuplicate: true,
            existingCaseId: existingCase._id,
            existingCaseTitle: existingCase.title,
            similarityScore: Math.round((matchCount / titleTokens.length) * 100),
          };
        }
      }
    } catch (err) {
      console.error("Duplicate check error:", err.message);
    }

    return { isDuplicate: false, similarityScore: 0 };
  }

  /**
   * Fetch REAL verified lawyers from MongoDB database
   * Sorted dynamically by rating DESC, experience DESC, win percentage DESC
   */
  async getRealLawyerRecommendations(category, specialization) {
    try {
      // Prefer lawyers matching the detected specialisation, then fall back to
      // any active lawyer. The previous filter required verified status OR a
      // non-zero rating OR non-zero experience, which excluded every
      // newly-onboarded lawyer and returned an empty list on a fresh database —
      // silently, because the caller swallows errors. An empty list meant no
      // lawyer was ever selected, so no appointment and no notification was
      // created when the case was filed.
      const specialisationFilter = [category, specialization]
        .filter(Boolean)
        .map((term) => ({ specialization: new RegExp(term, "i") }));

      let lawyers = [];

      if (specialisationFilter.length > 0) {
        lawyers = await Lawyer.find({ $or: specialisationFilter })
          .populate("user", "fullName email mobile profileImage role isActive")
          .sort({ verificationStatus: 1, rating: -1, experience: -1 })
          .limit(10);
      }

      if (lawyers.length === 0) {
        lawyers = await Lawyer.find({})
          .populate("user", "fullName email mobile profileImage role isActive")
          .sort({ rating: -1, experience: -1 })
          .limit(10);
      }

      // Every field below reports what the database actually holds.
      //
      // The previous version substituted invented values when a field was
      // absent — rating 4.8, winPercentage 88, casesHandled 95, 24 reviews,
      // "High Court Advocate" — so an unrated, unverified lawyer was presented
      // to a client as a highly-rated one. Fabricated credentials shown to
      // someone choosing legal representation are a compliance problem, not a
      // cosmetic one. Unknown values are now null; the UI must render them as
      // "New" or omit the metric.
      const formatted = lawyers
        .filter((l) => l.user != null && l.user.isActive !== false)
        .map((l) => ({
          lawyerId: l._id.toString(),
          userId: l.user._id.toString(),
          // The User schema field is `fullName`; `name` does not exist, so the
          // old code fell through to "Advocate" for every single lawyer.
          name: l.user.fullName || "Advocate",
          email: l.user.email || "",
          avatar: l.user.profileImage || "",
          specialization: l.specialization || "",
          experience: typeof l.experience === "number" ? l.experience : null,
          rating: l.rating > 0 ? l.rating : null,
          totalReviews: typeof l.totalReviews === "number" ? l.totalReviews : 0,
          consultationFee:
            typeof l.consultationFee === "number" ? l.consultationFee : null,
          winPercentage: l.winPercentage > 0 ? l.winPercentage : null,
          casesHandled: typeof l.casesHandled === "number" ? l.casesHandled : 0,
          officeAddress: l.officeAddress || "",
          isVerified: l.verificationStatus === "verified",
        }));

      return formatted;
    } catch (err) {
      console.error("Lawyer recommendation query error:", err.message);
      return [];
    }
  }
}

module.exports = new AiSmartIntakeService();
