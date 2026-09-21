/**
 * Canonical form of an email address for storage and lookup.
 *
 * The User schema declares `lowercase: true`, which Mongoose applies on write
 * but *not* to query values. So an account saved as "asha@example.com" was
 * invisible to `findOne({ email: "Asha@Example.com" })`, and a login typed with
 * any capital letter came back as "Invalid email or password." — the single
 * most common false rejection in this flow. The duplicate check in signup had
 * the mirror-image bug: it missed the existing row and let the write through,
 * where it died on the unique index instead.
 *
 * Every lookup by email goes through here so the query value is shaped the same
 * way the stored value is. Kept deliberately narrow — trim and lower-case only.
 * Provider-specific rewriting (stripping dots or "+tag" from Gmail) belongs at
 * the validation layer, where express-validator's normalizeEmail already does
 * it consistently for signup and login.
 */
const normalizeEmail = (email) =>
  typeof email === "string" ? email.trim().toLowerCase() : email;

module.exports = normalizeEmail;
