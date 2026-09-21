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
app.use((err, req, res, _next) => {
  const status = err.status || (err.message?.includes("Unsupported") ? 400 : 500);
  res.status(status).json({ success: false, message: err.message });
});

const tokenFor = (id) => jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: "1h" });
const auth = (id) => ({ Authorization: `Bearer ${tokenFor(id)}` });

const UPLOAD_DIR = path.resolve(__dirname, "../../uploads/acknowledgements");

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
    expect(res.body.data._id).toBe(doc._id);
    expect(res.body.data.clientId).toBe(OWNER);
    expect(res.body.data.fileSize).toBe(newBytes.length);
    expect(res.body.data.contentUpdatedAt).toBeTruthy();
    expect(fs.existsSync(oldAbsolute)).toBe(false);

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

describe("DOCX preview", () => {
  const zlib = require("zlib");

  const makeDocx = (body) => {
    const xml = `<?xml version="1.0"?><w:document xmlns:w="x"><w:body>${body}</w:body></w:document>`;
    const name = Buffer.from("word/document.xml", "utf8");
    const raw = Buffer.from(xml, "utf8");
    const deflated = zlib.deflateRawSync(raw);

    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(8, 8);
    local.writeUInt32LE(deflated.length, 18);
    local.writeUInt32LE(raw.length, 22);
    local.writeUInt16LE(name.length, 26);
    const localBlock = Buffer.concat([local, name, deflated]);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(8, 10);
    central.writeUInt32LE(deflated.length, 20);
    central.writeUInt32LE(raw.length, 24);
    central.writeUInt16LE(name.length, 28);
    central.writeUInt32LE(0, 42);
    const centralBlock = Buffer.concat([central, name]);

    const eocd = Buffer.alloc(22);
    eocd.writeUInt32LE(0x06054b50, 0);
    eocd.writeUInt16LE(1, 8);
    eocd.writeUInt16LE(1, 10);
    eocd.writeUInt32LE(centralBlock.length, 12);
    eocd.writeUInt32LE(localBlock.length, 16);

    return Buffer.concat([localBlock, centralBlock, eocd]);
  };

  const DOCX_MIME =
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

  const seedDocx = (bytes, overrides = {}) => {
    const doc = seedDocument({ mimeType: DOCX_MIME, ...overrides });
    const absolute = path.resolve(__dirname, "../..", doc.filePath);
    fs.writeFileSync(absolute, bytes);
    return doc;
  };

  it("converts a .docx into renderable blocks", async () => {
    const doc = seedDocx(
      makeDocx(
        `<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Petition</w:t></w:r></w:p>` +
          `<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Ananya Rao</w:t></w:r>` +
          `<w:r><w:t> v Vikram Sharma</w:t></w:r></w:p>`
      )
    );

    const res = await request(app)
      .get(`/api/documents/${doc._id}/preview`)
      .set(auth(OWNER));

    expect(res.status).toBe(200);
    expect(res.body.data.blocks[0]).toMatchObject({
      type: "heading",
      level: 1,
      text: "Petition",
    });
    expect(res.body.data.blocks[1].runs[0]).toMatchObject({
      text: "Ananya Rao",
      bold: true,
    });
    expect(res.body.data.truncated).toBe(false);
  });

  it("never returns HTML, only typed blocks", async () => {
    const doc = seedDocx(
      makeDocx(`<w:p><w:r><w:t>&lt;script&gt;alert(1)&lt;/script&gt;</w:t></w:r></w:p>`)
    );

    const res = await request(app)
      .get(`/api/documents/${doc._id}/preview`)
      .set(auth(OWNER));

    expect(res.status).toBe(200);
    expect(res.body.data.blocks[0].text).toBe("<script>alert(1)</script>");
    expect(res.body.data.blocks[0]).not.toHaveProperty("html");
  });

  it("refuses to preview another user's document", async () => {
    const doc = seedDocx(makeDocx(`<w:p><w:r><w:t>Private</w:t></w:r></w:p>`));

    const res = await request(app)
      .get(`/api/documents/${doc._id}/preview`)
      .set(auth(STRANGER));

    expect(res.status).toBe(404);
  });

  it("requires authentication", async () => {
    const doc = seedDocx(makeDocx(`<w:p><w:r><w:t>x</w:t></w:r></w:p>`));
    expect((await request(app).get(`/api/documents/${doc._id}/preview`)).status).toBe(401);
  });

  it("answers 415 for a format with no converter", async () => {
    const doc = seedDocument({ mimeType: "application/pdf" });

    const res = await request(app)
      .get(`/api/documents/${doc._id}/preview`)
      .set(auth(OWNER));

    expect(res.status).toBe(415);
    expect(res.body.message).toMatch(/cannot be previewed/i);
  });

  it("answers 422 for a .docx that will not parse", async () => {
    const doc = seedDocx(Buffer.from("this is not a zip archive at all"));

    const res = await request(app)
      .get(`/api/documents/${doc._id}/preview`)
      .set(auth(OWNER));

    expect(res.status).toBe(422);
    expect(res.body.message).toMatch(/damaged/i);
  });

  it("leaves the original file byte-for-byte unchanged", async () => {
    const bytes = makeDocx(`<w:p><w:r><w:t>Original</w:t></w:r></w:p>`);
    const doc = seedDocx(bytes);

    await request(app).get(`/api/documents/${doc._id}/preview`).set(auth(OWNER));

    const onDisk = fs.readFileSync(path.resolve(__dirname, "../..", doc.filePath));
    expect(onDisk.equals(bytes)).toBe(true);
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

  it("still removes the record when the file is already gone from disk", async () => {
    const doc = seedDocument();
    const absolute = path.resolve(__dirname, "../..", doc.filePath);
    fs.unlinkSync(absolute);
    expect(fs.existsSync(absolute)).toBe(false);

    const res = await request(app).delete(`/api/documents/${doc._id}`).set(auth(OWNER));

    expect(res.status).toBe(200);
    expect(mockDocs.find((d) => d._id === doc._id)).toBeUndefined();
  });

  it("requires authentication", async () => {
    const doc = seedDocument();
    const res = await request(app).delete(`/api/documents/${doc._id}`);

    expect(res.status).toBe(401);
    expect(mockDocs.find((d) => d._id === doc._id)).toBeDefined();
  });
});
