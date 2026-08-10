const express = require("express");
const multer = require("multer");
const aiController = require("../controllers/ai/aiController");
const aiSmartCaseController = require("../controllers/ai/aiSmartCaseController");

const authMiddleware = require("../middleware/authMiddleware");
const upload = require("../middleware/upload.middleware");

const router = express.Router();

/**
 * Turns a multer rejection into an answer the client can act on.
 *
 * Multer's errors reached the global handler as bare `Error`s with no status,
 * so an eleventh document or an unsupported format came back as a 500
 * "Internal Server Error" — which the client's retry logic treated as a
 * transient server fault and resent, several times, always failing the same
 * way. These are all 4xx: the request is wrong and resending it will not help.
 */
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

      // The only other rejection path is upload.middleware's fileFilter, which
      // rejects a MIME type outside the allowlist.
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

// Conversation management routes
router.get("/conversations", aiController.getConversations);
router.get("/conversations/:id", aiController.getConversationById);
router.post("/conversations", aiController.createConversation);
router.delete("/conversations/:id", aiController.deleteConversation);
router.delete("/conversations", aiController.deleteAllConversations);

// AI Smart Case Assistant Routes
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
