/**
 * Document management: list, search, rename, replace, view, download, delete.
 *
 * Routes, middleware and controller are real; only the Mongoose models are
 * in-memory, and the stored files are written to a real temp directory so the
 * streaming and replace paths touch an actual filesystem.
 */
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.NODE_ENV = "test";
process.env.BACKEND_URL = "http://localhost:5000";

const fs = require("fs");
const path = require("path");
const os = require("os");

const OWNER = "507f1f77bcf86cd799439011";
const STRANGER = "507f1f77bcf86cd799439022";

const mockDocs = [];
const mockState = { nextId: 1 };

jest.mock("../../src/models/User");
jest.mock("../../src/models/Case");
jest.mock("../../src/models/Message");
jest.mock("../../src/models/Notification");

jest.mock("../../src/models/Document", () => {
  const makeDoc = (data) => ({
    ...data,
    toObject() {
      const { toObject, save, ...rest } = this;
      return rest;
    },
    async save() {
      const i = mockDocs.findIndex((d) => String(d._id) === String(this._id));
      if (i >= 0) mockDocs[i] = this;
      return this;
    },
  });

  return {
    __makeDoc: makeDoc,
    create: async (data) => {
      const doc = makeDoc({ _id: `doc-${mockState.nextId++}`, name: "", ...data });
      mockDocs.push(doc);
      return doc;
    },
    findById: async (id) =>
      mockDocs.find((d) => String(d._id) === String(id)) || null,
    findByIdAndDelete: async (id) => {
      const i = mockDocs.findIndex((d) => String(d._id) === String(id));
      return i >= 0 ? mockDocs.splice(i, 1)[0] : null;
    },
    findOne: async () => null,
    find: (query) => {
      let rows = mockDocs.filter(
        (d) => !query.clientId || String(d.clientId) === String(query.clientId)
      );
      if (query.$or) {
        rows = rows.filter((d) =>
          query.$or.some((clause) => {
            const [field, cond] = Object.entries(clause)[0];
            return new RegExp(cond.$regex, cond.$options).test(d[field] || "");
          })
        );
      }
      if (query.mimeType?.$regex) {
        rows = rows.filter((d) => query.mimeType.$regex.test(d.mimeType || ""));
      }
      return {
        sort: async (spec) => {
          const [field, dir] = Object.entries(spec)[0];
          return [...rows].sort((a, b) => {
            const av = a[field] ?? "";
            const bv = b[field] ?? "";
            return (av > bv ? 1 : av < bv ? -1 : 0) * dir;
          });
        },
      };
    },
  };
});

const request = require("supertest");
const jwt = require("jsonwebtoken");
const User = require("../../src/models/User");
const Case = require("../../src/models/Case");
const Document = require("../../src/models/Document");

const express = require("express");
const documentRoutes = require("../../src/routes/document.routes");

const app = express();
app.use(express.json());
app.use("/api/documents", documentRoutes);
// Mirrors the real error handler closely enough for status assertions.
app.use((err, req, res, _next) => {
  const status = err.status || (err.message?.includes("Unsupported") ? 400 : 500);
  res.status(status).json({ success: false, message: err.message });
});

const tokenFor = (id) => jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: "1h" });
const auth = (id) => ({ Authorization: `Bearer ${tokenFor(id)}` });

const UPLOAD_DIR = path.resolve(__dirname, "../../uploads/acknowledgements");

/** Creates a document row backed by a file that really exists on disk. */
const seedDocument = (overrides = {}) => {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  const fileName = `test-${Date.now()}-${Math.random().toString(16).slice(2)}.pdf`;
  const absolute = path.join(UPLOAD_DIR, fileName);
  fs.writeFileSync(absolute, "%PDF-1.4 original bytes");

  const doc = Document.__makeDoc({
    _id: `doc-${mockState.nextId++}`,
    clientId: OWNER,
    originalName: "divorce_case_2026.pdf",
    name: "",
    fileName,
    filePath: `uploads/acknowledgements/${fileName}`,
    mimeType: "application/pdf",
    fileSize: 22,
    uploadedAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  });
  mockDocs.push(doc);
  return doc;
};

beforeEach(() => {
  jest.clearAllMocks();
  mockDocs.length = 0;

  User.findById.mockImplementation((id) => ({
    select: async () =>
      id === OWNER || id === STRANGER ? { _id: id, role: "client" } : null,
  }));
  Case.find.mockReturnValue({ distinct: async () => [] });
});

afterAll(() => {
  for (const d of mockDocs) {
    try { fs.unlinkSync(path.resolve(__dirname, "../..", d.filePath)); } catch {}
  }
});

describe("Document listing and search", () => {
  it("returns the owner's documents with a resolved display name", async () => {
    seedDocument({ name: "" });
    const res = await request(app).get("/api/documents").set(auth(OWNER));

    expect(res.status).toBe(200);
    // No custom name yet, so the display name falls back to the upload name.
    expect(res.body.data[0].name).toBe("divorce_case_2026.pdf");
  });

  it("does not return another user's documents", async () => {
    seedDocument();
    const res = await request(app).get("/api/documents").set(auth(STRANGER));

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(0);
  });

  it("searches on the renamed name and on the original name", async () => {
    seedDocument({ name: "Divorce Petition.pdf", originalName: "IMG_20260916.pdf" });

    const byNew = await request(app).get("/api/documents?search=petition").set(auth(OWNER));
    expect(byNew.body.data).toHaveLength(1);

    const byOld = await request(app).get("/api/documents?search=img_2026").set(auth(OWNER));
    expect(byOld.body.data).toHaveLength(1);

    const miss = await request(app).get("/api/documents?search=nothing").set(auth(OWNER));
    expect(miss.body.data).toHaveLength(0);
  });

  it("survives a search containing regex metacharacters", async () => {
    seedDocument({ name: "Exhibit (A).pdf" });

    const res = await request(app).get("/api/documents?search=(A)").set(auth(OWNER));
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
  });

  it("filters by file type family", async () => {
    seedDocument({ mimeType: "application/pdf" });
    seedDocument({ mimeType: "image/png" });

    const pdfs = await request(app).get("/api/documents?type=pdf").set(auth(OWNER));
    expect(pdfs.body.data).toHaveLength(1);

    const images = await request(app).get("/api/documents?type=image").set(auth(OWNER));
    expect(images.body.data).toHaveLength(1);

    const all = await request(app).get("/api/documents?type=all").set(auth(OWNER));
    expect(all.body.data).toHaveLength(2);
  });
});

describe("Rename", () => {
  it("renames and preserves the extension", async () => {
    const doc = seedDocument();
    const res = await request(app)
      .patch(`/api/documents/${doc._id}`)
      .set(auth(OWNER))
      .send({ name: "Sample Divorce Case" });

    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe("Sample Divorce Case.pdf");
  });

  it("does not double the extension when the user types it", async () => {
    const doc = seedDocument();
    const res = await request(app)
      .patch(`/api/documents/${doc._id}`)
      .set(auth(OWNER))
      .send({ name: "Sample Divorce Case.pdf" });

    expect(res.body.data.name).toBe("Sample Divorce Case.pdf");
  });

  it("persists the new name for later reads", async () => {
    const doc = seedDocument();
    await request(app)
      .patch(`/api/documents/${doc._id}`)
      .set(auth(OWNER))
      .send({ name: "Renamed" });

    const listed = await request(app).get("/api/documents").set(auth(OWNER));
    expect(listed.body.data[0].name).toBe("Renamed.pdf");
    // The upload name is kept alongside it.
    expect(listed.body.data[0].originalName).toBe("divorce_case_2026.pdf");
  });

  it("rejects an empty name", async () => {
    const doc = seedDocument();
    const res = await request(app)
      .patch(`/api/documents/${doc._id}`)
      .set(auth(OWNER))
      .send({ name: "   " });

    expect(res.status).toBe(400);
  });

  it("neutralises a path traversal attempt", async () => {
    const doc = seedDocument();
    const res = await request(app)
      .patch(`/api/documents/${doc._id}`)
      .set(auth(OWNER))
      .send({ name: "../../../etc/passwd" });

    expect(res.status).toBe(200);
    expect(res.body.data.name).not.toMatch(/[/\\]/);
    expect(res.body.data.name).toBe("etcpasswd.pdf");
  });

  it("refuses to rename someone else's document, revealing nothing", async () => {
    const doc = seedDocument();
    const res = await request(app)
      .patch(`/api/documents/${doc._id}`)
      .set(auth(STRANGER))
      .send({ name: "Stolen" });

    expect(res.status).toBe(404);
    expect(mockDocs[0].name).toBe("");
  });

  it("lets two documents share a display name", async () => {
    const a = seedDocument();
    const b = seedDocument();

    for (const doc of [a, b]) {
      const res = await request(app)
        .patch(`/api/documents/${doc._id}`)
        .set(auth(OWNER))
        .send({ name: "Sample Divorce Case" });
      expect(res.status).toBe(200);
    }

    const listed = await request(app).get("/api/documents").set(auth(OWNER));
    expect(listed.body.data.map((d) => d.name)).toEqual([
      "Sample Divorce Case.pdf",
      "Sample Divorce Case.pdf",
    ]);
    // Distinct identities and distinct files underneath.
    expect(listed.body.data[0]._id).not.toBe(listed.body.data[1]._id);
    expect(listed.body.data[0].filePath).not.toBe(listed.body.data[1].filePath);
  });
});

describe("View and download", () => {
  it("streams the document inline for viewing", async () => {
    const doc = seedDocument();
    const res = await request(app).get(`/api/documents/${doc._id}/view`).set(auth(OWNER));

    expect(res.status).toBe(200);
    expect(res.headers["content-type"]).toMatch(/application\/pdf/);
    expect(res.headers["content-disposition"]).toMatch(/^inline/);
    expect(res.headers["x-content-type-options"]).toBe("nosniff");
    expect(res.headers["cache-control"]).toMatch(/no-store/);
    // supertest does not populate `.text` for a binary content-type; the
    // streamed bytes arrive as a Buffer in `.body`.
    expect(res.body.toString()).toContain("original bytes");
  });

  it("downloads using the renamed filename", async () => {
    const doc = seedDocument();
    await request(app)
      .patch(`/api/documents/${doc._id}`)
      .set(auth(OWNER))
      .send({ name: "Divorce Case Final" });

    const res = await request(app).get(`/api/documents/${doc._id}/download`).set(auth(OWNER));

    expect(res.status).toBe(200);
    expect(res.headers["content-disposition"]).toMatch(/^attachment/);
    expect(res.headers["content-disposition"]).toContain('filename="Divorce Case Final.pdf"');
  });

  it("encodes a non-ASCII name without corrupting the header", async () => {
    const doc = seedDocument({ name: "విడాకుల పిటిషన్.pdf" });
    const res = await request(app).get(`/api/documents/${doc._id}/download`).set(auth(OWNER));

    expect(res.status).toBe(200);
    expect(res.headers["content-disposition"]).toContain("filename*=UTF-8''");
  });

  it("refuses to serve another user's document", async () => {
    const doc = seedDocument();

    expect((await request(app).get(`/api/documents/${doc._id}/view`).set(auth(STRANGER))).status).toBe(404);
    expect((await request(app).get(`/api/documents/${doc._id}/download`).set(auth(STRANGER))).status).toBe(404);
  });

  it("requires authentication", async () => {
    const doc = seedDocument();
    expect((await request(app).get(`/api/documents/${doc._id}/view`)).status).toBe(401);
  });

  it("reports a missing file rather than crashing", async () => {
    const doc = seedDocument();
    fs.unlinkSync(path.resolve(__dirname, "../..", doc.filePath));

    const res = await request(app).get(`/api/documents/${doc._id}/view`).set(auth(OWNER));
    expect(res.status).toBe(404);
  });

  it("serves a document stored with a leading-slash path", async () => {
    // The AI Smart Case intake writes filePath as "/uploads/cases/x.pdf".
    // path.resolve treats that as absolute, which previously placed it outside
    // the uploads root and 404'd every document the intake had created.
    const doc = seedDocument();
    doc.filePath = `/${doc.filePath}`;

    const res = await request(app).get(`/api/documents/${doc._id}/view`).set(auth(OWNER));

    expect(res.status).toBe(200);
    expect(res.body.toString()).toContain("original bytes");
  });

  it("refuses a stored path that escapes the uploads root", async () => {
    const doc = seedDocument({ filePath: "../../../../etc/passwd" });
    const res = await request(app).get(`/api/documents/${doc._id}/view`).set(auth(OWNER));

    expect(res.status).toBe(404);
    expect(String(res.text || res.body)).not.toContain("root:");
  });
});

describe("Replace", () => {
  const newBytes = Buffer.from("%PDF-1.4 REPLACEMENT bytes, longer than before");

  it("swaps the file, keeps the id, and removes the old file", async () => {
    const doc = seedDocument();
    const oldAbsolute = path.resolve(__dirname, "../..", doc.filePath);

    const res = await request(app)
      .post(`/api/documents/${doc._id}/replace`)
      .set(auth(OWNER))
      .attach("acknowledgement", newBytes, "replacement.pdf");

    expect(res.status).toBe(200);
    expect(res.body.data._id).toBe(doc._id);          // identity preserved
    expect(res.body.data.clientId).toBe(OWNER);        // ownership preserved
    expect(res.body.data.fileSize).toBe(newBytes.length);
    expect(res.body.data.contentUpdatedAt).toBeTruthy();
    expect(fs.existsSync(oldAbsolute)).toBe(false);    // old file cleaned up

    const served = await request(app).get(`/api/documents/${doc._id}/view`).set(auth(OWNER));
    const bytes = served.body.toString();
    expect(bytes).toContain("REPLACEMENT");
    expect(bytes).not.toContain("original bytes");
  });

  it("keeps a chosen name across the replacement", async () => {
    const doc = seedDocument({ name: "Divorce Petition.pdf" });

    const res = await request(app)
      .post(`/api/documents/${doc._id}/replace`)
      .set(auth(OWNER))
      .attach("acknowledgement", newBytes, "something_else.pdf");

    expect(res.body.data.name).toBe("Divorce Petition.pdf");
  });

  it("leaves the original intact when no file is sent", async () => {
    const doc = seedDocument();
    const before = fs.readFileSync(path.resolve(__dirname, "../..", doc.filePath), "utf8");

    const res = await request(app)
      .post(`/api/documents/${doc._id}/replace`)
      .set(auth(OWNER));

    expect(res.status).toBe(400);
    const after = fs.readFileSync(path.resolve(__dirname, "../..", doc.filePath), "utf8");
    expect(after).toBe(before);
  });

  it("refuses to replace another user's document", async () => {
    const doc = seedDocument();
    const before = fs.readFileSync(path.resolve(__dirname, "../..", doc.filePath), "utf8");

    const res = await request(app)
      .post(`/api/documents/${doc._id}/replace`)
      .set(auth(STRANGER))
      .attach("acknowledgement", newBytes, "replacement.pdf");

    expect(res.status).toBe(404);
    expect(fs.readFileSync(path.resolve(__dirname, "../..", doc.filePath), "utf8")).toBe(before);
  });

  it("rejects a disallowed file type", async () => {
    const doc = seedDocument();

    const res = await request(app)
      .post(`/api/documents/${doc._id}/replace`)
      .set(auth(OWNER))
      .attach("acknowledgement", Buffer.from("#!/bin/sh\nrm -rf /"), "evil.sh");

    expect(res.status).toBe(400);
    expect(fs.readFileSync(path.resolve(__dirname, "../..", doc.filePath), "utf8"))
      .toContain("original bytes");
  });
});

describe("Delete", () => {
  it("removes the record and the file", async () => {
    const doc = seedDocument();
    const absolute = path.resolve(__dirname, "../..", doc.filePath);

    const res = await request(app).delete(`/api/documents/${doc._id}`).set(auth(OWNER));

    expect(res.status).toBe(200);
    expect(fs.existsSync(absolute)).toBe(false);
    expect(mockDocs.find((d) => d._id === doc._id)).toBeUndefined();
  });

  it("refuses to delete another user's document", async () => {
    const doc = seedDocument();
    const res = await request(app).delete(`/api/documents/${doc._id}`).set(auth(STRANGER));

    expect(res.status).toBe(403);
    expect(mockDocs.find((d) => d._id === doc._id)).toBeDefined();
  });
});
