const express = require("express");
const caseController = require("../controllers/case/caseController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

// Apply authMiddleware globally to all case routes
router.use(authMiddleware);

router.post("/", caseController.createCase);
router.get("/", caseController.getCases);
router.get("/:id", caseController.getCaseById);
router.post("/:id/proposals", caseController.submitProposal);
router.post("/:id/accept", caseController.acceptProposal);
router.put("/:id/milestones", caseController.updateMilestone);

module.exports = router;
