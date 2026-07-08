const multer = require("multer");
const path = require("path");
const fs = require("fs");

// Define storage configuration
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    let folder = "documents";
    
    // Choose subfolder based on request endpoint or header hint
    const url = req.originalUrl || "";
    if (url.includes("/auth") || url.includes("/profile")) {
      folder = "profiles";
    } else if (url.includes("/issues") || url.includes("/cases")) {
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
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

// File filter validation
const fileFilter = (req, file, cb) => {
  const allowedTypes = [
    "application/pdf",
    "image/jpeg",
    "image/jpg",
    "image/png"
  ];
  
  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error("Only PDF, JPG, JPEG and PNG files are allowed."), false);
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
