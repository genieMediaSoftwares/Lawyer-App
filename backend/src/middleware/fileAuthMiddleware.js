const jwt = require("jsonwebtoken");
const User = require("../models/User");
const Document = require("../models/Document");
const Case = require("../models/Case");
const Message = require("../models/Message");

const PUBLIC_FOLDERS = new Set(["profiles"]);

const extractToken = (req) => {
  const header = req.headers.authorization;
  if (header && header.startsWith("Bearer ")) {
    return header.split(" ")[1];
  }

  const query = req.query.token;
  if (Array.isArray(query)) {
    const last = query.filter((v) => typeof v === "string" && v).pop();
    return last || null;
  }

  return typeof query === "string" && query ? query : null;
};

const canReadFile = async (user, relativePath, fileName) => {
  if (user.role === "admin") return true;

  const document = await Document.findOne({ filePath: relativePath });
  if (document) {
    if (document.clientId.toString() === user._id.toString()) return true;
    if (user.role !== "lawyer") return false;

    const engaged = await Case.exists({
      client: document.clientId,
      $or: [{ assignedLawyer: user._id }, { selectedLawyer: user._id }],
    });
    return Boolean(engaged);
  }

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

  const message = await Message.findOne({
    "attachments.url": { $regex: fileName },
  }).populate("chat");

  if (message && message.chat && Array.isArray(message.chat.participants)) {
    return message.chat.participants.some(
      (id) => id.toString() === user._id.toString()
    );
  }

  return false;
};

const fileAuthMiddleware = async (req, res, next) => {
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
