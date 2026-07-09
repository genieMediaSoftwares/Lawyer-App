const express = require("express");
const lawyerController = require("../controllers/lawyer/lawyerController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.use(authMiddleware);

router.get("/", lawyerController.getAllLawyers);
router.get("/recommend", lawyerController.recommendLawyers);
router.get("/match", lawyerController.match);
router.put("/profile", lawyerController.updateLawyerProfile);
router.get("/:id", lawyerController.getLawyerById);

module.exports = router;
