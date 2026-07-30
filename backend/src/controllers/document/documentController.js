const Document = require("../../models/Document");
const Case = require("../../models/Case");
const storageService = require("../../services/storageService");
const ApiResponse = require("../../config/ApiResponse");

/**
 * The set of client user-ids a lawyer is entitled to see documents for: the
 * clients on cases where this lawyer is selected or assigned.
 *
 * `Document.issueId` is not usable for this — it is nullable and the client
 * uploads documents before a case exists — so entitlement is derived from the
 * case relationship instead.
 */
const clientIdsVisibleToLawyer = (lawyerId) =>
  Case.find({
    $or: [{ assignedLawyer: lawyerId }, { selectedLawyer: lawyerId }],
  }).distinct("client");

/**
 * Builds the ownership filter for a document query. Admins are unrestricted;
 * everyone else is scoped. Note the default branch denies rather than allows —
 * a future role added to the enum must opt in explicitly instead of silently
 * inheriting access to every document in the system.
 */
const scopeForUser = async (user) => {
  if (user.role === "admin") return {};
  if (user.role === "lawyer") {
    return { clientId: { $in: await clientIdsVisibleToLawyer(user._id) } };
  }
  return { clientId: user._id };
};

const canAccessDocument = async (user, document) => {
  if (user.role === "admin") return true;
  if (user.role === "lawyer") {
    const clientIds = await clientIdsVisibleToLawyer(user._id);
    return clientIds.some((id) => id.toString() === document.clientId.toString());
  }
  return document.clientId.toString() === user._id.toString();
};

class DocumentController {
  async uploadDocument(req, res, next) {
    try {
      if (!req.file) {
        return ApiResponse.error(res, "No file uploaded.", 400);
      }

      const clientId = req.user._id;
      const issueId = req.body.issueId || null;

      // Extract metadata using Storage Service abstraction
      const metadata = await storageService.uploadFile(req.file, "documents");

      const document = await Document.create({
        clientId,
        issueId,
        originalName: metadata.originalName,
        fileName: metadata.fileName,
        filePath: metadata.filePath,
        mimeType: metadata.mimeType,
        fileSize: metadata.fileSize
      });

      return ApiResponse.success(res, "Document uploaded successfully.", document, 201);
    } catch (error) {
      next(error);
    }
  }

  async getDocumentById(req, res, next) {
    try {
      const { id } = req.params;
      const document = await Document.findById(id);
      
      if (!document) {
        return ApiResponse.error(res, "Document not found.", 404);
      }

      if (!(await canAccessDocument(req.user, document))) {
        return ApiResponse.error(res, "Unauthorized.", 403);
      }

      return ApiResponse.success(res, "Document details fetched successfully.", document);
    } catch (error) {
      next(error);
    }
  }

  async getDocuments(req, res, next) {
    try {
      const query = await scopeForUser(req.user);

      const documents = await Document.find(query).sort({ uploadedAt: -1 });
      return ApiResponse.success(res, "Documents fetched successfully.", documents);
    } catch (error) {
      next(error);
    }
  }

  async deleteDocument(req, res, next) {
    try {
      const { id } = req.params;
      const document = await Document.findById(id);
      
      if (!document) {
        return ApiResponse.error(res, "Document not found.", 404);
      }

      // Deletion is destructive, so it stays with the owning client (or an
      // admin) — a lawyer having read access to a client's document does not
      // entitle them to destroy it.
      const isOwner = document.clientId.toString() === req.user._id.toString();
      if (!isOwner && req.user.role !== "admin") {
        return ApiResponse.error(res, "Unauthorized.", 403);
      }

      // Remove physical file
      await storageService.deleteFile(document.filePath);

      // Remove db record
      await Document.findByIdAndDelete(id);

      return ApiResponse.success(res, "Document deleted successfully.", null);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new DocumentController();
