const express = require("express");
const router = express.Router();
const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");
const adminController = require("../controllers/admin/adminController");

router.use(authMiddleware);
router.use(roleMiddleware("admin"));

router.get("/stats", adminController.getAdminDashboardStats);

router.get("/clients", adminController.getClients);

router.get("/lawyers", adminController.getLawyers);
router.put("/lawyers/:lawyerId/verify", adminController.verifyLawyer);

router.get("/cases", adminController.getCases);
router.put("/cases/:caseId/status", adminController.updateCaseStatus);

router.get("/documents", adminController.getDocuments);

router.get("/ai-analytics", adminController.getAiAnalytics);

router.get("/support-tickets", adminController.getSupportTickets);
router.put("/support-tickets/:ticketId", adminController.updateSupportTicket);

router.post("/notifications/broadcast", adminController.broadcastNotification);

router.get("/analytics", adminController.getAnalyticsData);

router.get("/reports", adminController.getReportData);

module.exports = router;
