const jwt = require("jsonwebtoken");
const User = require("../models/User");
const Document = require("../models/Document");
const Case = require("../models/Case");
const Message = require("../models/Message");

/**
 * Folders under /uploads that are safe to serve without authentication.
 *
 * Profile images are shown to prospective clients browsing advocates, so they
 * are public by design. Everything else — case evidence, voice recordings of
 * case descriptions, bar-council certificates, acknowledgement documents — is
 * privileged material and must be authorised per request.
 */
const PUBLIC_FOLDERS = new Set(["profiles"]);

/**
 * Reads the bearer token from the Authorization header, falling back to a
 * `?token=` query parameter.
 *
 * The query fallback exists because these URLs are consumed by Image.network,
 * audioplayers and url_launcher, none of which attach headers. It is a
 * deliberate trade-off: tokens in URLs can end up in server logs and browser
 * history. Replacing this with short-lived signed URLs (a per-file HMAC with
 * its own expiry, not the session JWT) is the intended follow-up.
 */
const extractToken = (req) => {
  const header = req.headers.authorization;
  if (header && header.startsWith("Bearer ")) {
    return header.split(" ")[1];
  }
  return req.query.token || null;
};

/**
 * True if `user` is entitled to read the file stored at `relativePath`.
 *
 * Entitlement is resolved by finding the record that references the file and
 * applying that record's own access rule, rather than trusting the folder the
 * file happens to sit in.
 */
const canReadFile = async (user, relativePath, fileName) => {
  if (user.role === "admin") return true;

  // Acknowledgement / client documents.
  const document = await Document.findOne({ filePath: relativePath });
  if (document) {
    if (document.clientId.toString() === user._id.toString()) return true;
    if (user.role !== "lawyer") return false;

    // A lawyer may read a client's document only while engaged on that
    // client's case.
    const engaged = await Case.exists({
      client: document.clientId,
      $or: [{ assignedLawyer: user._id }, { selectedLawyer: user._id }],
    });
    return Boolean(engaged);
  }

  // Case documents and voice recordings. Matched on the filename because
  // these are stored as absolute (or differently-rooted) URLs rather than
  // relative paths — see storageService.uploadFile and the AI smart-case
  // intake, which write `documents[].url`.
  const relatedCase = await Case.findOne({
    $or: [
      { "documents.url": { $regex: fileName } },
      { voiceUrl: { $regex: fileName } },
    ],
  }).select("client assignedLawyer selectedLawyer");

  if (relatedCase) {
    return [
      relatedCase.client,
      relatedCase.assignedLawyer,
      relatedCase.selectedLawyer,
    ]
      .filter(Boolean)
      .some((id) => id.toString() === user._id.toString());
  }

  // Chat attachments — readable by the participants of the conversation.
  const message = await Message.findOne({
    "attachments.url": { $regex: fileName },
  }).populate("chat");

  if (message && message.chat && Array.isArray(message.chat.participants)) {
    return message.chat.participants.some(
      (id) => id.toString() === user._id.toString()
    );
  }

  // Nothing references this file. Deny — an orphaned upload is not a reason
  // to hand it out.
  return false;
};

const fileAuthMiddleware = async (req, res, next) => {
  // req.path here is relative to the /uploads mount, e.g. "/cases/172-ab.mp3"
  const segments = req.path.split("/").filter(Boolean);
  const [folder, fileName] = segments;

  if (PUBLIC_FOLDERS.has(folder)) {
    return next();
  }

  if (!folder || !fileName || segments.length !== 2) {
    return res.status(404).json({ success: false, message: "Not found." });
  }

  const token = extractToken(req);
  if (!token) {
    return res
      .status(401)
      .json({ success: false, message: "Access denied. No token provided." });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.id).select("-password");

    if (!user) {
      return res.status(401).json({ success: false, message: "User not found." });
    }

    const relativePath = `uploads/${folder}/${fileName}`;
    if (!(await canReadFile(user, relativePath, fileName))) {
      // 404 rather than 403: a 403 would confirm the file exists.
      return res.status(404).json({ success: false, message: "Not found." });
    }

    return next();
  } catch (error) {
    return res
      .status(401)
      .json({ success: false, message: "Invalid or expired token." });
  }
};

module.exports = fileAuthMiddleware;
