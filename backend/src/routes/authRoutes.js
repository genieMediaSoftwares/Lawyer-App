const express = require("express");

const router = express.Router();

const authController = require("../controllers/auth/authController");

const authMiddleware = require("../middleware/authMiddleware");

const validationMiddleware = require("../middleware/validationMiddleware");

const {
  signupValidation,
  loginValidation,
  emailValidation,
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

// emailValidation normalises the address exactly as signup and login do, so a
// reset request finds the account it was typed for regardless of casing.
router.post(
  "/forgot-password",
  emailValidation,
  validationMiddleware,
  authController.forgotPassword
);
router.post(
  "/reset-password",
  emailValidation,
  validationMiddleware,
  authController.resetPassword
);
router.post("/change-password", authMiddleware, authController.changePassword);
router.post("/delete-account", authMiddleware, authController.deleteAccount);


// Was a stub that acknowledged the request and did nothing. The session it was
// supposed to end stayed open, so the account looked signed-in for another
// seven days and the next login anywhere reported a device conflict.
router.post("/logout", authMiddleware, authController.logout);

// Was a stub that answered "Token refreshed." and issued nothing, so an
// expired access token could never actually be renewed and the only way back in
// was to sign in again. Now rotates the calling device's refresh token and
// returns a new access token for that session alone.
//
// No authMiddleware: this is reached when the access token has already expired.
router.post("/refresh-token", authController.refreshToken);

// Signs the account out on every device. Distinct from /logout, which ends only
// the session the caller is holding.
router.post("/logout-all", authMiddleware, authController.logoutAllDevices);

router.post(
  "/profile/certificate",
  authMiddleware,
  upload.single("certificate"),
  authController.uploadBarCertificate
);

module.exports = router;