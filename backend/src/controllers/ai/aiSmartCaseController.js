const ApiResponse = require("../../config/ApiResponse");
const AiSmartCaseSession = require("../../models/AiSmartCaseSession");
const Case = require("../../models/Case");
const Appointment = require("../../models/Appointment");
const ocrSanitizationService = require("../../services/ai/ocrSanitizationService");
const aiSmartIntakeService = require("../../services/ai/aiSmartIntakeService");
const notificationService = require("../../services/notification/notificationService");
const gemini = require("../../services/ai/geminiClient");
const fs = require("fs");
const path = require("path");

class AiSmartCaseController {
  /**
   * POST /api/ai/smart-case/analyze
   * Upload multiple documents and optional voice recording to analyze with AI
   */
  async analyzeSmartCase(req, res, next) {
    try {
      const clientId = req.user._id;

      // Extract uploaded files from Multer
      const documentFiles = req.files?.documents || (Array.isArray(req.files) ? req.files : []);
      const voiceFile = req.files?.voice ? req.files.voice[0] : (req.file || null);

      let aggregatedOcrText = "";
      const documentMetadata = [];
      const allFraudFlags = [];
      const uploadedDocsForDb = [];
      const extractionFailures = [];

      // 1. Process Documents (OCR & Sanitization)
      //
      // Run in parallel. OCR takes 13-45s per file against Gemini, so the
      // original sequential loop meant 10 documents could take six minutes and
      // exceed any sane client timeout. Order is preserved because
      // Promise.all resolves positionally.
      if (documentFiles && documentFiles.length > 0) {
        const ocrResults = await Promise.all(
          documentFiles.map((file) =>
            ocrSanitizationService
              .extractText(file.path, file.mimetype, file.originalname)
              .catch((err) => ({
                // A single unreadable document must not fail the whole intake.
                extractedText: "",
                ocrQuality: "Extraction Unavailable",
                fraudFlags: [],
                charCount: 0,
                extractionFailed: true,
                extractionError: err.message,
              }))
          )
        );

        documentFiles.forEach((file, index) => {
          const ocrResult = ocrResults[index];

          // Must include the sub-folder. upload.middleware routes /api/ai/*
          // uploads to uploads/cases/, so the old `/uploads/${filename}` URL
          // pointed at a path that does not exist and every stored document
          // link 404'd. Derived from file.path so the two can't drift again.
          const fileUrl =
            "/" + path.relative(path.join(__dirname, "../../.."), file.path).replace(/\\/g, "/");

          // Only feed real extracted text to the model. Appending an empty or
          // placeholder body used to leave the AI inferring case details from
          // the filename alone.
          if (ocrResult.extractedText && ocrResult.extractedText.trim()) {
            aggregatedOcrText +=
              `\n\n--- DOCUMENT: ${file.originalname} ---\n` + ocrResult.extractedText;
          }

          if (ocrResult.extractionFailed) {
            extractionFailures.push({
              name: file.originalname,
              reason: ocrResult.extractionError || "OCR service unavailable",
            });
          }

          if (ocrResult.fraudFlags && ocrResult.fraudFlags.length > 0) {
            allFraudFlags.push(...ocrResult.fraudFlags);
          }

          documentMetadata.push({
            name: file.originalname,
            size: `${(file.size / 1024).toFixed(1)} KB`,
            type: file.mimetype,
            ocrQuality: ocrResult.ocrQuality,
            charactersExtracted: ocrResult.charCount,
          });

          uploadedDocsForDb.push({
            originalName: file.originalname,
            mimeType: file.mimetype,
            size: file.size,
            path: file.path,
            url: fileUrl,
            documentType: file.mimetype,
            ocrQuality: ocrResult.ocrQuality,
          });
        });
      }

      // 2. Transcribe Voice if provided
      let voiceTranscript = req.body.voiceTranscript || "";
      let voiceTranscriptionFailed = false;

      if (voiceFile && !voiceTranscript) {
        try {
          const audioBase64 = fs.readFileSync(voiceFile.path).toString("base64");
          // Routed through geminiClient so a model outage falls back instead of
          // failing outright, as it did when this was pinned to gemini-2.0-flash.
          const { text } = await gemini.generate(
            [
              {
                inlineData: {
                  mimeType: voiceFile.mimetype || "audio/mp4",
                  data: audioBase64,
                },
              },
              {
                text:
                  "Transcribe this voice description of a legal issue verbatim into English. " +
                  "Return ONLY the plain transcript, with no commentary.",
              },
            ],
            { label: "smart-case:transcribe" }
          );

          voiceTranscript = text || "";
          voiceTranscriptionFailed = !text;
        } catch (vErr) {
          console.error("Voice transcription failed in intake:", vErr.message);
          voiceTranscriptionFailed = true;
        }
      }

      const typedDescription = (req.body.issueDescription || "").trim();

      // Fall back to whatever the client typed. Never substitute a synthetic
      // sentence like "General legal intake submission." — the model treated
      // that as the client's actual account of their problem and generated a
      // case title and legal category from it.
      if (!aggregatedOcrText.trim() && !voiceTranscript.trim()) {
        voiceTranscript = typedDescription;
      }

      // With no document text, no transcript and nothing typed there is
      // nothing to analyse. Record the failure so the session history shows
      // what happened rather than leaving an invented case behind.
      if (!aggregatedOcrText.trim() && !voiceTranscript.trim()) {
        await AiSmartCaseSession.create({
          client: clientId,
          status: "failed",
          uploadedDocuments: uploadedDocsForDb,
          voiceTranscript: "",
        });

        const reason = extractionFailures.length
          ? "We could not read any text from the uploaded document(s)."
          : "No document text, voice recording or description was provided.";

        return ApiResponse.error(
          res,
          `${reason} Please add a short description of your issue, or upload a clearer document, and try again.`,
          422
        );
      }

      // 3. AI Intake Processing via Gemini Pro
      const analysisResult = await aiSmartIntakeService.analyzeCaseIntake({
        ocrText: aggregatedOcrText,
        voiceTranscript,
        documentMetadata,
        clientId,
      });

      // Merge fraud flags from OCR & Gemini
      const combinedFraudFlags = [
        ...allFraudFlags,
        ...(analysisResult.aiAnalysis.fraudFlags || []),
      ];
      analysisResult.aiAnalysis.fraudFlags = Array.from(new Set(combinedFraudFlags));

      // 4. Save Session in MongoDB
      const session = await AiSmartCaseSession.create({
        client: clientId,
        status: analysisResult.aiAnalysis.aiConfidenceScore >= 90 ? "reviewed" : "questions_pending",
        uploadedDocuments: uploadedDocsForDb,
        ocrExtractedText: aggregatedOcrText,
        voiceTranscript,
        aiAnalysis: analysisResult.aiAnalysis,
        duplicateCheck: analysisResult.duplicateCheck,
        recommendedLawyers: analysisResult.recommendedLawyers.map((l) => l.userId),
      });

      return ApiResponse.success(res, "AI Smart Case analysis completed successfully.", {
        sessionId: session._id.toString(),
        status: session.status,
        aiAnalysis: analysisResult.aiAnalysis,
        duplicateCheck: analysisResult.duplicateCheck,
        recommendedLawyers: analysisResult.recommendedLawyers,
        uploadedDocuments: uploadedDocsForDb,
        voiceTranscript,
        // Told to the client so the review screen can say which documents were
        // not read, instead of implying the analysis covered everything.
        extractionWarnings: extractionFailures,
        voiceTranscriptionFailed,
      });
    } catch (error) {
      console.error("Analyze Smart Case Error:", error);

      // Leave a trace of the failure. The "failed" status existed in the
      // session enum but nothing ever set it, so a crashed analysis vanished.
      try {
        await AiSmartCaseSession.create({
          client: req.user?._id,
          status: "failed",
          voiceTranscript: "",
        });
      } catch {
        // Session bookkeeping must not mask the original error.
      }

      next(error);
    }
  }

  /**
   * POST /api/ai/smart-case/answer-questions
   * Submit answers to follow-up questions to refine case readiness & confidence
   */
  async answerSmartCaseQuestions(req, res, next) {
    try {
      const { sessionId, answers } = req.body;
      const clientId = req.user._id;

      const session = await AiSmartCaseSession.findOne({ _id: sessionId, client: clientId });
      if (!session) {
        return ApiResponse.error(res, "AI Case Session not found.", 404);
      }

      session.userAnswers = answers || [];

      // Re-run AI analysis with answers included
      const formattedAnswersText = (answers || [])
        .map((a) => `Q: ${a.question}\nA: ${a.answer}`)
        .join("\n\n");

      const refinedText = session.ocrExtractedText + "\n\n=== ADDITIONAL CLIENT ANSWERS ===\n" + formattedAnswersText;

      const refinedResult = await aiSmartIntakeService.analyzeCaseIntake({
        ocrText: refinedText,
        voiceTranscript: session.voiceTranscript,
        documentMetadata: session.uploadedDocuments,
        clientId,
      });

      session.aiAnalysis = refinedResult.aiAnalysis;
      session.status = "reviewed";
      await session.save();

      return ApiResponse.success(res, "Answers processed and case updated successfully.", {
        sessionId: session._id.toString(),
        status: session.status,
        aiAnalysis: session.aiAnalysis,
        duplicateCheck: session.duplicateCheck,
        recommendedLawyers: refinedResult.recommendedLawyers,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/ai/smart-case/confirm-create
   * Confirm and officially create the Case in MongoDB with real lawyer assignment & socket notifications
   */
  async confirmCreateSmartCase(req, res, next) {
    try {
      const {
        sessionId,
        title,
        description,
        category,
        priority,
        selectedLawyerId,
        location,
        urgency,
        budgetRange,
      } = req.body;
      const clientId = req.user._id;

      let session = null;
      if (sessionId) {
        session = await AiSmartCaseSession.findOne({ _id: sessionId, client: clientId });
      }

      const caseTitle = title || session?.aiAnalysis?.caseTitle || "AI Assistance Case";
      const caseDescription = description || session?.aiAnalysis?.caseDescription || "Case generated via AI Smart Case Assistant.";
      const caseCategory = category || session?.aiAnalysis?.category || "General Legal";
      const caseUrgency = urgency || priority || session?.aiAnalysis?.priority || "Flexible";

      // Process attached documents
      const caseDocuments = (session?.uploadedDocuments || []).map((doc) => ({
        name: doc.originalName,
        url: doc.url,
        size: `${(doc.size / 1024).toFixed(1)} KB`,
      }));

      // 1. Create real Case in MongoDB
      const newCase = await Case.create({
        client: clientId,
        title: caseTitle,
        description: caseDescription,
        category: caseCategory,
        location: location || "Delhi NCR, India",
        urgency: caseUrgency,
        budgetRange: budgetRange || "Market Standard",
        status: selectedLawyerId ? "Awaiting Lawyer Acceptance" : "Submitted",
        selectedLawyer: selectedLawyerId || null,
        documents: caseDocuments,
        voiceTranscript: session?.voiceTranscript || "",
      });

      // 2. Create Appointment Request if lawyer is selected
      //
      // These field names must match the Appointment schema exactly. They did
      // not: `appointmentDate` (schema: `date`, and required), `type` (schema:
      // `mode`), `status: "Pending"` (enum is lowercase) and `type: "Online"`
      // (enum is Chat | In-Person). Mongoose rejected every insert, so
      // selecting a lawyer made the whole confirm-create request fail with a
      // 500 — after the Case had already been written.
      let appointment = null;
      if (selectedLawyerId) {
        // Non-fatal: the Case is already persisted at this point, so throwing
        // here would leave the client with a 500 and an orphaned case they
        // cannot see. Report the case as created and log the shortfall.
        try {
          appointment = await Appointment.create({
            client: clientId,
            lawyer: selectedLawyerId,
            case: newCase._id,
            date: new Date(Date.now() + 24 * 60 * 60 * 1000), // Tomorrow
            timeSlot: "10:00 AM - 11:00 AM",
            mode: "Chat",
            status: "pending",
            notes: `AI Smart Case Intake: ${caseTitle}`,
          });
        } catch (aErr) {
          console.error("Appointment creation failed for case", newCase._id.toString(), aErr.message);
        }

        // 3. Emit Real-time Socket.io Notifications to Lawyer & Client
        const io = req.app.get("io");
        if (io) {
          try {
            io.of("/notifications").to(selectedLawyerId.toString()).emit("notification", {
              type: "NEW_CASE_ASSIGNMENT",
              title: "New AI Smart Case Assigned",
              message: `You have received a new case: "${caseTitle}"`,
              caseId: newCase._id.toString(),
            });

            io.of("/cases").to(selectedLawyerId.toString()).emit("new_case_assigned", {
              caseId: newCase._id.toString(),
              title: caseTitle,
              category: caseCategory,
            });
          } catch (sErr) {
            console.error("Socket emission error:", sErr.message);
          }
        }

        // Send in-app notification record.
        //
        // Was calling a non-existent `sendNotification` with the wrong keys
        // (`userId`/`body`/`relatedId`), so it threw
        // "sendNotification is not a function" into a swallowing catch and the
        // lawyer was never notified that a case had been assigned to them.
        try {
          await notificationService.createAndSendNotification({
            senderId: clientId,
            receiverId: selectedLawyerId,
            title: "New Case Received",
            message: `A client assigned the case "${caseTitle}" to you via the AI Assistant.`,
            type: "case_posted",
            priority: "high",
            referenceId: newCase._id.toString(),
          });
        } catch (nErr) {
          console.error("Notification service error:", nErr.message);
        }
      }

      // Update Session Status
      if (session) {
        session.status = "created";
        session.createdCase = newCase._id;
        // Clean OCR text from session to save memory as required by DB rules
        session.ocrExtractedText = "";
        await session.save();
      }

      return ApiResponse.success(res, "Case created successfully!", {
        case: newCase,
        appointment,
      });
    } catch (error) {
      console.error("Confirm Create Smart Case Error:", error);
      next(error);
    }
  }

  /**
   * GET /api/ai/smart-case/history
   * Retrieve previous AI intake sessions for the client to resume anytime
   */
  async getSmartCaseHistory(req, res, next) {
    try {
      const clientId = req.user._id;
      const sessions = await AiSmartCaseSession.find({ client: clientId })
        .sort({ updatedAt: -1 })
        .populate("createdCase", "title status createdAt");

      return ApiResponse.success(res, "AI Smart Case sessions retrieved successfully.", {
        sessions,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/ai/smart-case/session/:id
   * Fetch single session details
   */
  async getSmartCaseSessionById(req, res, next) {
    try {
      const { id } = req.params;
      const clientId = req.user._id;

      const session = await AiSmartCaseSession.findOne({ _id: id, client: clientId })
        .populate("createdCase")
        .populate("recommendedLawyers");

      if (!session) {
        return ApiResponse.error(res, "Session not found.", 404);
      }

      return ApiResponse.success(res, "Session retrieved successfully.", { session });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AiSmartCaseController();
