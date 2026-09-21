const express = require("express");
const caseController = require("../controllers/case/caseController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

// Apply authMiddleware globally to all case routes
router.use(authMiddleware);

router.post("/", caseController.createCase);
router.get("/", caseController.getCases);
router.get("/status/in-progress", caseController.getInProgressCases);
router.get("/status/closed", caseController.getClosedCases);

// Hearings. Court hearings on a case - distinct from the consultation
// appointments served by /api/appointments, which keep their own model,
// endpoints and Google Calendar sync.
router.get("/hearings/mine", caseController.getMyHearings);

router.get("/:id/timeline", caseController.getCaseTimeline);
router.get("/:id/lawyer", caseController.getCaseLawyer);
router.get("/:id", caseController.getCaseById);
router.post("/:id/proposals", caseController.submitProposal);
router.post("/:id/accept", caseController.acceptProposal);
router.post("/:id/reject", caseController.rejectProposal);
router.post("/:id/accept-request", caseController.acceptCaseRequest);
router.post("/:id/reject-request", caseController.rejectCaseRequest);
router.post("/:id/start", caseController.startCase);
router.post("/:id/complete", caseController.markCaseCompleted);
router.put("/:id/milestones", caseController.updateMilestone);
router.post("/:id/review", caseController.submitCaseReview);
router.post("/:id/hearings", caseController.addHearing);
router.put("/:id/hearings/:hearingId", caseController.updateHearing);
router.delete("/:id/hearings/:hearingId", caseController.deleteHearing);

module.exports = router;
