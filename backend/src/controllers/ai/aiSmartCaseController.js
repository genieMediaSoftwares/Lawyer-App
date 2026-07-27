const ApiResponse = require("../../config/ApiResponse");
const AiSmartCaseSession = require("../../models/AiSmartCaseSession");
const Case = require("../../models/Case");
const Appointment = require("../../models/Appointment");
const ocrSanitizationService = require("../../services/ai/ocrSanitizationService");
const aiSmartIntakeService = require("../../services/ai/aiSmartIntakeService");
const notificationService = require("../../services/notification/notificationService");
const fs = require("fs");

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

      // 1. Process Documents (OCR & Sanitization)
      if (documentFiles && documentFiles.length > 0) {
        for (const file of documentFiles) {
          const fileUrl = `/uploads/${file.filename}`;
          const ocrResult = await ocrSanitizationService.extractText(
            file.path,
            file.mimetype,
            file.originalname
          );

          aggregatedOcrText += `\n\n--- DOCUMENT: ${file.originalname} ---\n` + ocrResult.extractedText;

          if (ocrResult.fraudFlags && ocrResult.fraudFlags.length > 0) {
            allFraudFlags.push(...ocrResult.fraudFlags);
          }

          documentMetadata.push({
            name: file.originalname,
            size: `${(file.size / 1024).toFixed(1)} KB`,
            type: file.mimetype,
            ocrQuality: ocrResult.ocrQuality,
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
        }
      }

      // 2. Transcribe Voice if provided
      let voiceTranscript = req.body.voiceTranscript || "";
      if (voiceFile && !voiceTranscript) {
        try {
          const apiKey = process.env.GEMINI_API_KEY;
          if (apiKey) {
            const audioBuffer = fs.readFileSync(voiceFile.path);
            const audioBase64 = audioBuffer.toString("base64");
            let mimeType = voiceFile.mimetype || "audio/mp4";

            const transcribeRes = await fetch(
              `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
              {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  contents: [
                    {
                      role: "user",
                      parts: [
                        { inlineData: { mimeType, data: audioBase64 } },
                        { text: "Transcribe this voice audio description of a legal issue verbatim into English text. Return ONLY plain English transcript." },
                      ],
                    },
                  ],
                }),
              }
            );

            if (transcribeRes.ok) {
              const trData = await transcribeRes.json();
              voiceTranscript = trData.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || "";
            }
          }
        } catch (vErr) {
          console.error("Voice transcription failed in intake:", vErr.message);
        }
      }

      if (!aggregatedOcrText.trim() && !voiceTranscript.trim()) {
        voiceTranscript = req.body.issueDescription || "General legal intake submission.";
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
      });
    } catch (error) {
      console.error("Analyze Smart Case Error:", error);
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
      let appointment = null;
      if (selectedLawyerId) {
        appointment = await Appointment.create({
          client: clientId,
          lawyer: selectedLawyerId,
          case: newCase._id,
          appointmentDate: new Date(Date.now() + 24 * 60 * 60 * 1000), // Tomorrow
          timeSlot: "10:00 AM - 11:00 AM",
          type: "Online",
          status: "Pending",
          notes: `AI Smart Case Intake: ${caseTitle}`,
        });

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

        // Send in-app notification record
        try {
          await notificationService.sendNotification({
            userId: selectedLawyerId,
            title: "New Case Received",
            body: `Client assigned case "${caseTitle}" to you via AI Assistant.`,
            type: "case_update",
            relatedId: newCase._id.toString(),
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
