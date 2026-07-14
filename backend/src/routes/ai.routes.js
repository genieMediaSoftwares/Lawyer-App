const express = require("express");
const aiController = require("../controllers/ai/aiController");
const authMiddleware = require("../middleware/authMiddleware");
const upload = require("../middleware/upload.middleware");

const router = express.Router();

router.use(authMiddleware);

router.post("/chat", aiController.chat);
router.post("/transcribe", upload.single("audio"), aiController.transcribe);

module.exports = router;
