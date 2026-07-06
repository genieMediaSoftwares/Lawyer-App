const express = require("express");
const reviewController = require("../controllers/review/reviewController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.use(authMiddleware);

router.post("/", reviewController.createReview);
router.get("/", reviewController.getReviews);
router.put("/:id/reply", reviewController.replyToReview);
router.put("/:id/hide", reviewController.hideReview);
router.post("/:id/report", reviewController.reportReview);

module.exports = router;
