const Document = require("../../models/Document");
const Case = require("../../models/Case");
const storageService = require("../../services/storageService");
const notificationService = require("../../services/notification/notificationService");
const ApiResponse = require("../../config/ApiResponse");
const fs = require("fs");
const path = require("path");
const {
  displayName,
  sanitiseDisplayName,
  contentDisposition,
} = require("../../utils/documentName");

/**
 * Absolute path of a stored document, refusing anything that escapes the
 * uploads root.
 *
 * `filePath` is written by storageService and is not user input, but it is read
 * back out of the database and turned into a filesystem read — so it is
 * re-validated here rather than trusted. A row altered by any other means
 * cannot be used to serve /etc/passwd.
 */
const UPLOAD_ROOT = path.resolve(__dirname, "../../../uploads");

const resolveStoredPath = (document) => {
  // Two writers produce `filePath` in two shapes: storageService yields
  // "uploads/acknowledgements/x.pdf", while the AI intake yields
  // "/uploads/cases/x.pdf". path.resolve treats the second as ABSOLUTE, which
  // sent it outside the uploads root and made every AI-uploaded document 404
  // on view and download. Leading separators are stripped so both shapes are
  // resolved relative to the project, and the containment check below is
  // unchanged — a real "../" still fails it.
  let stored = String(document.filePath || "");
  while (stored.startsWith("/") || stored.startsWith("\\")) {
    stored = stored.slice(1);
  }
  const absolute = path.resolve(__dirname, "../../..", stored);
  const relative = path.relative(UPLOAD_ROOT, absolute);

  if (!relative || relative.startsWith("..") || path.isAbsolute(relative)) {
    return null;
  }

  return absolute;
};

/**
 * The shape the client receives. Adds the resolved display name so the app
 * never has to know that `name` falls back to `originalName`.
 */
const publicDocument = (document) => {
  const plain = typeof document.toObject === "function"
    ? document.toObject()
    : { ...document };

  return { ...plain, name: displayName(document) };
};

/**
 * Streams a stored document, inline for viewing or as an attachment for
 * download. Shared by both so the authorisation and the headers cannot drift
 * apart between them.
 */
const sendStoredFile = async (req, res, disposition) => {
  const { id } = req.params;
  const document = await Document.findById(id);

  if (!document) {
    return ApiResponse.error(res, "Document not found.", 404);
  }

  if (!(await canAccessDocument(req.user, document))) {
    // 404, not 403: a 403 confirms the id exists, which turns this endpoint
    // into a way of enumerating other people's documents.
    return ApiResponse.error(res, "Document not found.", 404);
  }

  const absolutePath = resolveStoredPath(document);

  if (!absolutePath || !fs.existsSync(absolutePath)) {
    return ApiResponse.error(res, "Document file is no longer available.", 404);
  }

  res.setHeader("Content-Type", document.mimeType || "application/octet-stream");
  res.setHeader(
    "Content-Disposition",
    contentDisposition(disposition, displayName(document))
  );
  // Never let an upload be interpreted as active content on our origin, and
  // never let a proxy or browser cache privileged material.
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Content-Security-Policy", "default-src 'none'");
  res.setHeader("Cache-Control", "private, no-store");

  const { size } = fs.statSync(absolutePath);

  // Range support. A PDF reader opening a large file asks for the trailer
  // first, then individual objects, rather than reading from byte zero — so
  // without this it has to pull the whole document before showing page one.
  // Advertised even when the client does not ask, because a reader decides
  // whether to range-request based on this header.
  res.setHeader("Accept-Ranges", "bytes");

  const rangeHeader = req.headers.range;
  let streamOptions;

  if (rangeHeader) {
    // Only the single-range form, "bytes=START-END", is honoured. Multipart
    // ranges are legal but no PDF reader sends them, and answering one
    // incorrectly is worse than declining to.
    const match = /^bytes=(\d*)-(\d*)$/.exec(rangeHeader.trim());

    if (!match || (match[1] === "" && match[2] === "")) {
      res.setHeader("Content-Range", `bytes */${size}`);
      return res.status(416).end();
    }

    let start;
    let end;

    if (match[1] === "") {
      // "bytes=-500" means the LAST 500 bytes, not the first.
      const suffixLength = Number(match[2]);
      start = Math.max(0, size - suffixLength);
      end = size - 1;
    } else {
      start = Number(match[1]);
      end = match[2] === "" ? size - 1 : Math.min(Number(match[2]), size - 1);
    }

    if (!Number.isFinite(start) || !Number.isFinite(end) || start > end || start >= size) {
      res.setHeader("Content-Range", `bytes */${size}`);
      return res.status(416).end();
    }

    res.status(206);
    res.setHeader("Content-Range", `bytes ${start}-${end}/${size}`);
    res.setHeader("Content-Length", end - start + 1);
    streamOptions = { start, end };
  } else {
    res.setHeader("Content-Length", size);
  }

  // Streamed, not read into memory: a 10MB cap per file still means a handful
  // of concurrent downloads holding the heap open for no reason.
  const stream = fs.createReadStream(absolutePath, streamOptions);
  stream.on("error", (error) => {
    console.error("Document stream failed:", error.message);
    if (!res.headersSent) {
      ApiResponse.error(res, "Unable to read this document.", 500);
    } else {
      res.destroy();
    }
  });

  return stream.pipe(res);
};

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
    // Two sets, not one: documents the lawyer uploaded THEMSELVES, and
    // documents belonging to clients they are engaged with.
    //
    // `uploadDocument` stores `clientId: req.user._id`, so a lawyer's own
    // upload is owned by the lawyer — their id, not a client's. Scoping only
    // to `clientIdsVisibleToLawyer` therefore excluded every document the
    // lawyer had uploaded for themselves: the upload returned 201 and the file
    // then never appeared in their list and could not be opened. That is what
    // made the lawyer Documents section look broken while the client one
    // worked.
    return {
      $or: [
        { clientId: user._id },
        { clientId: { $in: await clientIdsVisibleToLawyer(user._id) } },
      ],
    };
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

/** True when this user owns the document outright. */
const isOwner = (user, document) =>
  document.clientId.toString() === user._id.toString();

const canAccessDocument = async (user, document) => {
  if (user.role === "admin") return true;

  // Owning it is sufficient for everyone, lawyers included — this is the check
  // that was missing for a lawyer's own uploads. See scopeForUser.
  if (isOwner(user, document)) return true;

  if (user.role === "lawyer") {
    const clientIds = await clientIdsVisibleToLawyer(user._id);
    return clientIds.some((id) => id.toString() === document.clientId.toString());
  }

  return false;
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

      return ApiResponse.success(
        res,
        "Document uploaded successfully.",
        publicDocument(document),
        201
      );
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

      return ApiResponse.success(
        res,
        "Document details fetched successfully.",
        publicDocument(document)
      );
    } catch (error) {
      next(error);
    }
  }

  async getDocuments(req, res, next) {
    try {
      const query = await scopeForUser(req.user);

      // Search covers both the display name and the name it was uploaded
      // under, so a renamed document is still findable by what it used to be
      // called. Escaped before it reaches $regex: an unescaped "(" from a
      // client is a crashing regex, and ".*" would be a cheap way to scan.
      const search = String(req.query.search || "").trim();
      if (search) {
        const escaped = search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        query.$or = [
          { name: { $regex: escaped, $options: "i" } },
          { originalName: { $regex: escaped, $options: "i" } },
        ];
      }

      // Filter by family rather than by exact MIME type, so "images" means all
      // of them and a new image format does not need a client release.
      const TYPE_FILTERS = {
        pdf: /^application\/pdf$/i,
        doc: /wordprocessingml|msword/i,
        image: /^image\//i,
        text: /^text\//i,
        audio: /^audio\//i,
      };
      const type = String(req.query.type || "").trim().toLowerCase();
      if (type && type !== "all" && TYPE_FILTERS[type]) {
        query.mimeType = { $regex: TYPE_FILTERS[type] };
      }

      const SORTS = {
        recent: { uploadedAt: -1 },
        oldest: { uploadedAt: 1 },
        modified: { updatedAt: -1 },
        name_asc: { name: 1, originalName: 1 },
        name_desc: { name: -1, originalName: -1 },
        size_desc: { fileSize: -1 },
        size_asc: { fileSize: 1 },
      };
      const sort = SORTS[String(req.query.sort || "").trim()] || SORTS.recent;

      const documents = await Document.find(query).sort(sort);

      return ApiResponse.success(
        res,
        "Documents fetched successfully.",
        documents.map(publicDocument)
      );
    } catch (error) {
      next(error);
    }
  }

  /**
   * Renames a document. Metadata only — the stored file is never touched, so
   * two documents may share a display name without colliding on disk.
   */
  async renameDocument(req, res, next) {
    try {
      const document = await Document.findById(req.params.id);

      if (!document) {
        return ApiResponse.error(res, "Document not found.", 404);
      }

      // Renaming is an owner's right, not a reader's: a lawyer who may READ a
      // client's document must not be able to retitle it. Admins are excepted
      // for support.
      const isOwner = document.clientId.toString() === req.user._id.toString();
      if (!isOwner && req.user.role !== "admin") {
        return ApiResponse.error(res, "Document not found.", 404);
      }

      const result = sanitiseDisplayName(req.body?.name, document);
      if (!result.ok) {
        return ApiResponse.error(res, result.reason, 400);
      }

      document.name = result.name;
      await document.save();

      return ApiResponse.success(
        res,
        "Document renamed successfully.",
        publicDocument(document)
      );
    } catch (error) {
      next(error);
    }
  }

  /**
   * Swaps the stored file for a new one, keeping the document's identity.
   *
   * The id, owner and case association survive, so every reference elsewhere
   * in the app still resolves. The order matters and is the whole point: the
   * new file is already on disk (multer wrote it before this ran) and the
   * database is updated first; only then is the old file removed. A failure at
   * any earlier point leaves the original document completely intact.
   */
  async replaceDocument(req, res, next) {
    let uploadedPath = req.file?.path || null;

    try {
      if (!req.file) {
        return ApiResponse.error(res, "No replacement file uploaded.", 400);
      }

      const document = await Document.findById(req.params.id);

      if (!document) {
        return ApiResponse.error(res, "Document not found.", 404);
      }

      const isOwner = document.clientId.toString() === req.user._id.toString();
      if (!isOwner && req.user.role !== "admin") {
        return ApiResponse.error(res, "Document not found.", 404);
      }

      const previousPath = document.filePath;
      const metadata = await storageService.uploadFile(req.file, "documents");

      // The display name follows the new file unless the owner had renamed the
      // document — a chosen title describes the matter, not the bytes, so it
      // survives. The extension is re-derived either way, because replacing a
      // PDF with a DOCX must not leave the name claiming ".pdf".
      const hadCustomName = Boolean((document.name || "").trim());
      document.originalName = metadata.originalName;
      document.fileName = metadata.fileName;
      document.filePath = metadata.filePath;
      document.mimeType = metadata.mimeType;
      document.fileSize = metadata.fileSize;
      document.contentUpdatedAt = new Date();

      if (hadCustomName) {
        const stem = path.parse(document.name).name;
        const renamed = sanitiseDisplayName(stem, document);
        document.name = renamed.ok ? renamed.name : metadata.originalName;
      } else {
        document.name = "";
      }

      await document.save();

      // Committed. The replacement is now the document of record, so losing
      // the old file is untidy rather than harmful — it must not fail the
      // request the client has already been told nothing about yet.
      uploadedPath = null;
      if (previousPath && previousPath !== document.filePath) {
        try {
          await storageService.deleteFile(previousPath);
        } catch (cleanupError) {
          console.error(
            "⚠️ replaced document: old file could not be removed:",
            cleanupError.message
          );
        }
      }

      return ApiResponse.success(
        res,
        "Document replaced successfully.",
        publicDocument(document)
      );
    } catch (error) {
      // The replacement never became the document of record, so the file
      // multer wrote is an orphan. Remove it and leave the original alone.
      if (uploadedPath) {
        fs.promises.unlink(uploadedPath).catch(() => {});
      }
      next(error);
    }
  }

  /** Streams the document for viewing in place. */
  async viewDocument(req, res, next) {
    try {
      return await sendStoredFile(req, res, "inline");
    } catch (error) {
      next(error);
    }
  }

  /** Streams the document as a download, named as the owner named it. */
  async downloadDocument(req, res, next) {
    try {
      return await sendStoredFile(req, res, "attachment");
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
