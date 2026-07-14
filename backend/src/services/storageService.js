const fs = require("fs");
const path = require("path");

class StorageService {
  /**
   * Upload file (metadata builder for local file)
   * In a real S3 integration, this would upload the file to S3 and return the S3 URL.
   */
  async uploadFile(file, folder = "documents") {
    // For local storage, the file is already stored in the destination folder by Multer.
    // We construct the public URL path and return the metadata.
    const relativePath = path.relative(path.join(__dirname, "../.."), file.path).replace(/\\/g, "/");
    const backendUrl = process.env.BACKEND_URL;
    if (!backendUrl) {
      throw new Error("BACKEND_URL is not defined in the environment variables.");
    }
    const fileUrl = `${backendUrl}/${relativePath}`;

    return {
      originalName: file.originalname,
      fileName: file.filename,
      filePath: relativePath,
      mimeType: file.mimetype,
      fileSize: file.size,
      url: fileUrl
    };
  }

  /**
   * Delete file from local storage
   */
  async deleteFile(filePath) {
    return new Promise((resolve, reject) => {
      const fullPath = path.join(__dirname, "../..", filePath);
      if (fs.existsSync(fullPath)) {
        fs.unlink(fullPath, (err) => {
          if (err) return reject(err);
          resolve(true);
        });
      } else {
        resolve(false);
      }
    });
  }
}

module.exports = new StorageService();
