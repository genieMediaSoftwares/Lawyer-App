const express = require("express");
const documentController = require("../controllers/document/documentController");
const upload = require("../middleware/upload.middleware");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.use(authMiddleware);

router.post("/upload", upload.single("file"), documentController.uploadDocument);
router.get("/", documentController.getDocuments);
router.delete("/:id", documentController.deleteDocument);

module.exports = router;
