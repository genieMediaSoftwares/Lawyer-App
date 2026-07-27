const express = require("express");
const aiController = require("../controllers/ai/aiController");
const aiSmartCaseController = require("../controllers/ai/aiSmartCaseController");
const authMiddleware = require("../middleware/authMiddleware");
const upload = require("../middleware/upload.middleware");

const router = express.Router();

router.use(authMiddleware);

router.post("/chat", aiController.chat);
router.post("/transcribe", upload.single("audio"), aiController.transcribe);

// Conversation management routes
router.get("/conversations", aiController.getConversations);
router.get("/conversations/:id", aiController.getConversationById);
router.post("/conversations", aiController.createConversation);
router.delete("/conversations/:id", aiController.deleteConversation);
router.delete("/conversations", aiController.deleteAllConversations);

// AI Smart Case Assistant Routes
router.post(
  "/smart-case/analyze",
  upload.fields([
    { name: "documents", maxCount: 10 },
    { name: "voice", maxCount: 1 },
  ]),
  aiSmartCaseController.analyzeSmartCase
);
router.post("/smart-case/answer-questions", aiSmartCaseController.answerSmartCaseQuestions);
router.post("/smart-case/confirm-create", aiSmartCaseController.confirmCreateSmartCase);
router.get("/smart-case/history", aiSmartCaseController.getSmartCaseHistory);
router.get("/smart-case/session/:id", aiSmartCaseController.getSmartCaseSessionById);

module.exports = router;
