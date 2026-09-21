const express = require("express");
const paymentController = require("../controllers/payment/paymentController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/webhook", paymentController.handleWebhook);

router.use(authMiddleware);

router.post("/create-consultation-order", paymentController.createConsultationOrder);
router.post("/verify", paymentController.verifyPayment);

router.get("/earnings", paymentController.getEarnings);
router.post("/withdraw", paymentController.requestWithdrawal);
router.get("/transactions", paymentController.getTransactions);
router.post("/checkout", paymentController.checkout);

module.exports = router;
