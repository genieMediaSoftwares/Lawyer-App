const { body } = require("express-validator");

const signupValidation = [
  body("fullName")
    .trim()
    .notEmpty()
    .withMessage("Full Name is required")
    .isLength({ min: 3 })
    .withMessage("Full Name must be at least 3 characters"),

  body("email")
    .trim()
    .isEmail()
    .withMessage("Valid email is required")
    .normalizeEmail(),

  body("mobile")
    .trim()
    .matches(/^[6-9]\d{9}$/)
    .withMessage("Enter a valid 10-digit mobile number"),

  body("password")
    .isLength({ min: 6 })
    .withMessage("Password must be at least 6 characters"),

  body("role")
    .optional()
    .isIn(["client", "lawyer"])
    .withMessage("Role must be client or lawyer"),
];

const loginValidation = [
  // normalizeEmail must match signupValidation exactly. It did not before: the
  // address was canonicalised on the way in and left raw on the way back, so
  // an account registered as "Asha@Example.com" (stored "asha@example.com")
  // could not be found by the very string its owner had typed to create it,
  // and the login came back "Invalid email or password."
  body("email")
    .trim()
    .isEmail()
    .withMessage("Valid email is required")
    .normalizeEmail(),

  body("password")
    .notEmpty()
    .withMessage("Password is required"),
];

/** Address-only payloads: forgot-password and reset-password. */
const emailValidation = [
  body("email")
    .trim()
    .isEmail()
    .withMessage("Valid email is required")
    .normalizeEmail(),
];

module.exports = {
  signupValidation,
  loginValidation,
  emailValidation,
};