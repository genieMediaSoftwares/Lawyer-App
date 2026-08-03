const Document = require("../../models/Document");
const Case = require("../../models/Case");
const storageService = require("../../services/storageService");
const notificationService = require("../../services/notification/notificationService");
const ApiResponse = require("../../config/ApiResponse");

/// Cases where the two sides are actually working together. A document upload
/// is worth interrupting the other party for on these; on a case still waiting
/// to be accepted, or already closed, it is noise.
const ENGAGED_CASE_STATUSES = ["Accepted", "In Progress"];

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

/**
 * Tells the other side of each engaged case that a document arrived.
 *
 * `Document.issueId` cannot be used to pick a single case — it references an
 * Issue, not a Case, and is null for most uploads — so the counterparties are
 * derived from the uploader's engaged cases instead, deduplicated so a client
 * working with the same lawyer on two matters is told once.
 */
const notifyCounterpartiesOfUpload = async (user, document) => {
  const isLawyer = user.role === "lawyer";
  const cases = await Case.find({
    status: { $in: ENGAGED_CASE_STATUSES },
    ...(isLawyer
      ? { $or: [{ assignedLawyer: user._id }, { selectedLawyer: user._id }] }
      : { client: user._id }),
  })
    .select("client assignedLawyer selectedLawyer title")
    .lean();

  const notified = new Set();
  for (const caseItem of cases) {
    const receiverId = isLawyer
      ? caseItem.client
      : caseItem.assignedLawyer || caseItem.selectedLawyer;
    if (!receiverId || notified.has(receiverId.toString())) continue;
    notified.add(receiverId.toString());

    const who = user.fullName || (isLawyer ? "Your lawyer" : "Your client");
    await notificationService.createAndSendNotification({
      senderId: user._id,
      receiverId,
      type: "document_uploaded",
      title: "New Document Uploaded",
      message: caseItem.title
        ? `${who} uploaded a new document in "${caseItem.title}".`
        : `${who} uploaded a new document.`,
      referenceId: document._id.toString(),
    });
  }
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

      try {
        await notifyCounterpartiesOfUpload(req.user, document);
      } catch (notifyError) {
        // Best-effort: the file is stored and the upload succeeded. Failing
        // the request because an alert could not be raised would tell the
        // user their document did not save, which is untrue.
        console.error(
          "⚠️ document_uploaded notification failed:",
          notifyError.message
        );
      }

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
