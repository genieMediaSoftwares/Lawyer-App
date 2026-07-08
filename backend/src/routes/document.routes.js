const express = require("express");
const documentController = require("../controllers/document/documentController");
const upload = require("../middleware/upload.middleware");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.use(authMiddleware);

router.post("/upload", upload.single("acknowledgement"), documentController.uploadDocument);
router.get("/:id", documentController.getDocumentById);
router.get("/", documentController.getDocuments);
router.delete("/:id", documentController.deleteDocument);

module.exports = router;
