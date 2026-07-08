const Document = require("../../models/Document");
const storageService = require("../../services/storageService");
const ApiResponse = require("../../config/ApiResponse");

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

      // Check ownership
      if (req.user.role === "client" && document.clientId.toString() !== req.user._id.toString()) {
        return ApiResponse.error(res, "Unauthorized.", 403);
      }

      return ApiResponse.success(res, "Document details fetched successfully.", document);
    } catch (error) {
      next(error);
    }
  }

  async getDocuments(req, res, next) {
    try {
      let query = {};
      if (req.user.role === "client") {
        query.clientId = req.user._id;
      }
      
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

      // Check ownership
      if (req.user.role === "client" && document.clientId.toString() !== req.user._id.toString()) {
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
