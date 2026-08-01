const multer = require("multer");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");

// Canonical extension per accepted MIME type. Membership in this map *is* the
// allowlist — a type absent here cannot be uploaded and cannot be named.
// "application/octet-stream" is deliberately excluded: any client can claim it
// for any bytes, which made the previous allowlist a no-op.
const EXTENSION_BY_MIME = {
  "application/pdf": ".pdf",
  "image/jpeg": ".jpg",
  "image/jpg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  // "application/msword" (.doc) is intentionally absent. It is a pre-2007
  // binary compound file: Gemini cannot read it and there is no text extractor
  // for it here, so accepting one only produced an unreadable document and a
  // confusing failure. Clients are asked for PDF/DOCX/image/TXT instead.
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx",
  "text/plain": ".txt",
  "text/markdown": ".md",
  "text/csv": ".csv",
  "audio/mpeg": ".mp3",
  "audio/mp3": ".mp3",
  "audio/wav": ".wav",
  "audio/m4a": ".m4a",
  "audio/x-m4a": ".m4a",
  "audio/mp4": ".m4a",
  "audio/webm": ".webm",
  "audio/ogg": ".ogg",
  "audio/aac": ".aac",
  "audio/3gpp": ".3gp",
  "audio/amr": ".amr",
};

// Define storage configuration
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    let folder = "documents";
    
    // Choose subfolder based on request endpoint or header hint
    const url = req.originalUrl || "";
    if (url.includes("/auth") || url.includes("/profile")) {
      folder = "profiles";
    } else if (url.includes("/issues") || url.includes("/cases") || url.includes("/ai")) {
      folder = "cases";
    } else if (url.includes("/certificates")) {
      folder = "certificates";
    } else if (url.includes("/documents")) {
      folder = "acknowledgements";
    }

    const uploadPath = path.join(__dirname, "../../uploads", folder);
    
    // Ensure directory exists
    fs.mkdirSync(uploadPath, { recursive: true });
    cb(null, uploadPath);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix =
      Date.now() + "-" + crypto.randomBytes(8).toString("hex");

    // Derive the extension from the validated MIME type, never from the
    // client-supplied filename. Trusting originalname let an attacker keep a
    // ".html" (or ".svg") extension on an upload and have it served back as
    // active content from our own origin.
    cb(null, uniqueSuffix + EXTENSION_BY_MIME[file.mimetype]);
  }
});

// File filter validation
const fileFilter = (req, file, cb) => {
  if (Object.prototype.hasOwnProperty.call(EXTENSION_BY_MIME, file.mimetype)) {
    cb(null, true);
  } else {
    cb(
      new Error(
        "Unsupported file type. Allowed: PDF, PNG, JPG, WEBP, DOCX, TXT, CSV and audio."
      ),
      false
    );
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB limit
  }
});

module.exports = upload;
