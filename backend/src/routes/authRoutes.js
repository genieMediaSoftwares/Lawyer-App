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

module.exports = router;