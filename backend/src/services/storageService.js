const fs = require("fs");
const path = require("path");

class StorageService {
  async uploadFile(file, folder = "documents") {
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
