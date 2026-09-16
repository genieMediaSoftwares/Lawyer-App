const express = require("express");
const documentController = require("../controllers/document/documentController");
const upload = require("../middleware/upload.middleware");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

// Every document route is authenticated. Authorisation is then checked per
// document inside the controller — being signed in says nothing about whether
// this particular file is yours.
router.use(authMiddleware);

router.post(
  "/upload",
  upload.single("acknowledgement"),
  documentController.uploadDocument
);

// Listing supports ?search= &type= &sort=, applied in the database rather than
// by shipping every document to the client and filtering there.
router.get("/", documentController.getDocuments);

// Declared before "/:id" so "view" and "download" are not swallowed as ids.
router.get("/:id/view", documentController.viewDocument);
router.get("/:id/download", documentController.downloadDocument);

router.get("/:id", documentController.getDocumentById);

// Rename. PATCH because it updates one field of an existing document.
router.patch("/:id", documentController.renameDocument);

// Replace the stored file while keeping the document's identity, so every
// existing reference to this id still resolves.
router.post(
  "/:id/replace",
  upload.single("acknowledgement"),
  documentController.replaceDocument
);

router.delete("/:id", documentController.deleteDocument);

module.exports = router;
