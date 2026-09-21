const express = require("express");
const multer = require("multer");
const aiController = require("../controllers/ai/aiController");
const aiSmartCaseController = require("../controllers/ai/aiSmartCaseController");
const researchController = require("../controllers/ai/researchController");

const authMiddleware = require("../middleware/authMiddleware");
const upload = require("../middleware/upload.middleware");

const router = express.Router();

function handleUploadErrors(uploadMiddleware) {
  return (req, res, next) => {
    uploadMiddleware(req, res, (err) => {
      if (!err) return next();

      if (err instanceof multer.MulterError) {
        const messages = {
          LIMIT_FILE_SIZE: "Each file must be 10 MB or smaller.",
          LIMIT_FILE_COUNT: "You can attach up to 10 documents.",
          LIMIT_UNEXPECTED_FILE:
            "You can attach up to 10 documents and one voice note.",
          LIMIT_PART_COUNT: "Too many parts in the upload.",
        };
        return res.status(400).json({
          success: false,
          message: messages[err.code] || "That upload could not be accepted.",
        });
      }

      return res.status(415).json({
        success: false,
        message: err.message || "Unsupported file type.",
      });
    });
  };
}

router.use(authMiddleware);

router.post("/chat", aiController.chat);
router.post(
  "/transcribe",
  handleUploadErrors(upload.single("audio")),
  aiController.transcribe
);

router.get("/research/cases", researchController.listCases);
router.get("/research/cases/:caseId/documents", researchController.listDocuments);
router.post("/research/sessions", researchController.startCaseResearch);
router.post("/research/:id/relevant-cases", researchController.searchRelevantCases);

router.get("/conversations", aiController.getConversations);
router.get("/conversations/:id", aiController.getConversationById);
router.post("/conversations", aiController.createConversation);
router.delete("/conversations/:id", aiController.deleteConversation);
router.delete("/conversations", aiController.deleteAllConversations);

router.post(
  "/smart-case/analyze",
  handleUploadErrors(
    upload.fields([
      { name: "documents", maxCount: 10 },
      { name: "voice", maxCount: 1 },
    ])
  ),
  aiSmartCaseController.analyzeSmartCase
);
router.get("/smart-case/history", aiSmartCaseController.getSmartCaseHistory);
router.get("/smart-case/session/:id", aiSmartCaseController.getSmartCaseSessionById);
router.post("/smart-case/session/:id/link-case", aiSmartCaseController.linkSessionToCase);

module.exports = router;
