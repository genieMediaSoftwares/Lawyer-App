const express = require("express");

const router = express.Router();

const authController = require("../controllers/auth/authController");

const authMiddleware = require("../middleware/authMiddleware");

const validationMiddleware = require("../middleware/validationMiddleware");

const {
  signupValidation,
  loginValidation,
} = require("../validations/authValidation");

router.post(
  "/signup",
  signupValidation,
  validationMiddleware,
  authController.signup
);

router.post(
  "/login",
  loginValidation,
  validationMiddleware,
  authController.login
);

router.get(
  "/profile",
  authMiddleware,
  authController.profile
);

const upload = require("../middleware/upload.middleware");

router.put(
  "/profile",
  authMiddleware,
  authController.updateProfile
);

router.post(
  "/profile/image",
  authMiddleware,
  upload.single("image"),
  authController.uploadProfileImage
);

router.post("/forgot-password", authController.forgotPassword);
router.post("/reset-password", authController.resetPassword);
router.post("/change-password", authMiddleware, authController.changePassword);

router.post("/logout", authMiddleware, (req, res) => {
  return res.status(200).json({ success: true, message: "Logged out successfully." });
});

router.post("/refresh-token", (req, res) => {
  // Mock endpoint for refreshing JWT token
  return res.status(200).json({ success: true, message: "Token refreshed." });
});

router.post(
  "/profile/certificate",
  authMiddleware,
  upload.single("certificate"),
  authController.uploadBarCertificate
);

module.exports = router;