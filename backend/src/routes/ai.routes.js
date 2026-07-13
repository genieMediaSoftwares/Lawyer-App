const express = require("express");
const aiController = require("../controllers/ai/aiController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.use(authMiddleware);

router.post("/chat", aiController.chat);

module.exports = router;
