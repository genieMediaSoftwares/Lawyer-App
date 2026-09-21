const multer = require("multer");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");
const { AI_OPTIMIZE_MAX_INPUT_BYTES } = require("../config/uploadLimits");

const EXTENSION_BY_MIME = {
  "application/pdf": ".pdf",
  "image/jpeg": ".jpg",
  "image/jpg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
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


const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    let folder = "documents";
    
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
    
    fs.mkdirSync(uploadPath, { recursive: true });
    cb(null, uploadPath);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix =
      Date.now() + "-" + crypto.randomBytes(8).toString("hex");

    const ext = EXTENSION_BY_MIME[file.mimetype] || path.extname(file.originalname);
    cb(null, uniqueSuffix + ext);
  }
});

const ALLOWED_EXTENSIONS = new Set([
  ".pdf", ".jpg", ".jpeg", ".png", ".webp", ".docx", ".txt", ".md", ".csv",
  ".mp3", ".wav", ".m4a", ".webm", ".ogg", ".aac", ".3gp", ".amr"
]);

const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname || "").toLowerCase();
  if (
    Object.prototype.hasOwnProperty.call(EXTENSION_BY_MIME, file.mimetype) ||
    ALLOWED_EXTENSIONS.has(ext)
  ) {
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
    fileSize: 10 * 1024 * 1024
  }
});

// Raw PDFs sent to the AI assistant for optimization may be larger than the
// normal limit; they are shrunk before anything keeps them.
upload.optimizeInput = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: AI_OPTIMIZE_MAX_INPUT_BYTES,
    files: 1
  }
});

module.exports = upload;
