const express = require("express");
const paymentController = require("../controllers/payment/paymentController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.use(authMiddleware);

router.get("/earnings", paymentController.getEarnings);
router.post("/withdraw", paymentController.requestWithdrawal);
router.get("/transactions", paymentController.getTransactions);
router.post("/checkout", paymentController.checkout);

module.exports = router;
