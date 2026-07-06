const express = require("express");
const notificationController = require("../controllers/notification/notificationController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.use(authMiddleware);

router.get("/", notificationController.getNotifications);
router.put("/:id/read", notificationController.markAsRead);

module.exports = router;
