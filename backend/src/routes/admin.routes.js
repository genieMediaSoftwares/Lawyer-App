const express = require("express");
const router = express.Router();
const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");
const adminController = require("../controllers/admin/adminController");

// Protect all admin routes
router.use(authMiddleware);
router.use(roleMiddleware("admin"));

// 1. Dashboard Stats
router.get("/stats", adminController.getAdminDashboardStats);

// 2. Client Management
router.get("/clients", adminController.getClients);

// 3. Lawyer Management & Verification
router.get("/lawyers", adminController.getLawyers);
router.put("/lawyers/:lawyerId/verify", adminController.verifyLawyer);

// 4. Case Management
router.get("/cases", adminController.getCases);
router.put("/cases/:caseId/status", adminController.updateCaseStatus);

// 5. Document Management
router.get("/documents", adminController.getDocuments);

// 6. AI Analytics
router.get("/ai-analytics", adminController.getAiAnalytics);

// 7. Support Tickets
router.get("/support-tickets", adminController.getSupportTickets);
router.put("/support-tickets/:ticketId", adminController.updateSupportTicket);

// 8. Notifications Broadcast
router.post("/notifications/broadcast", adminController.broadcastNotification);

// 9. Analytics Data
router.get("/analytics", adminController.getAnalyticsData);

// 10. Reports Export Data
router.get("/reports", adminController.getReportData);

module.exports = router;
