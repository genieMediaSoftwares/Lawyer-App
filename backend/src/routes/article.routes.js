const express = require("express");
const articleController = require("../controllers/article/articleController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

// Allow public/auth route access
router.get("/", articleController.getArticles);
router.get("/:id", articleController.getArticleById);
router.post("/:id/bookmark", authMiddleware, articleController.toggleBookmark);

module.exports = router;
