process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.NODE_ENV = "test";
process.env.BACKEND_URL = "http://localhost:5000";

const fs = require("fs");
const path = require("path");

const OWNER = "507f1f77bcf86cd799439011";
const mockDocs = [];
const mockState = { nextId: 1 };

jest.mock("../../src/models/User");
jest.mock("../../src/models/Case");
jest.mock("../../src/models/Message");

jest.mock("../../src/models/Document", () => ({
  __push: (doc) => mockDocs.push(doc),
  findById: async (id) => mockDocs.find((d) => String(d._id) === String(id)) || null,
  findOne: async () => null,
  find: () => ({ sort: async () => [...mockDocs] }),
}));

const request = require("supertest");
const jwt = require("jsonwebtoken");
const express = require("express");
const User = require("../../src/models/User");
const Case = require("../../src/models/Case");
const Document = require("../../src/models/Document");
const documentRoutes = require("../../src/routes/document.routes");

const app = express();
app.use(express.json());
app.use("/api/documents", documentRoutes);

const auth = () => ({
  Authorization: `Bearer ${jwt.sign({ id: OWNER }, process.env.JWT_SECRET, { expiresIn: "1h" })}`,
});

const UPLOAD_DIR = path.resolve(__dirname, "../../uploads/acknowledgements");

const BODY = Buffer.from(
  Array.from({ length: 100 }, (_, i) => String(i % 10).repeat(10)).join("")
);

let doc;

beforeEach(() => {
  jest.clearAllMocks();
  mockDocs.length = 0;

  User.findById.mockImplementation((id) => ({
    select: async () => (id === OWNER ? { _id: id, role: "client" } : null),
  }));
  Case.find.mockReturnValue({ distinct: async () => [] });

  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  const fileName = `range-${mockState.nextId++}-${Date.now()}.pdf`;
  fs.writeFileSync(path.join(UPLOAD_DIR, fileName), BODY);

  doc = {
    _id: "doc-range",
    clientId: OWNER,
    originalName: "big.pdf",
    name: "Big Document.pdf",
    fileName,
    filePath: `uploads/acknowledgements/${fileName}`,
    mimeType: "application/pdf",
    fileSize: BODY.length,
    uploadedAt: new Date(),
    toObject() {
      const { toObject, ...rest } = this;
      return rest;
    },
  };
  Document.__push(doc);
});

afterEach(() => {
  try {
    fs.unlinkSync(path.resolve(__dirname, "../..", doc.filePath));
  } catch {}
});

describe("Range requests on /view", () => {
  it("advertises range support and the full length when none is asked for", async () => {
    const res = await request(app).get("/api/documents/doc-range/view").set(auth());

    expect(res.status).toBe(200);
    expect(res.headers["accept-ranges"]).toBe("bytes");
    expect(res.headers["content-length"]).toBe(String(BODY.length));
    expect(res.body.length).toBe(BODY.length);
  });

  it("serves an explicit byte range as 206", async () => {
    const res = await request(app)
      .get("/api/documents/doc-range/view")
      .set({ ...auth(), Range: "bytes=10-19" });

    expect(res.status).toBe(206);
    expect(res.headers["content-range"]).toBe(`bytes 10-19/${BODY.length}`);
    expect(res.headers["content-length"]).toBe("10");
    expect(res.body.toString()).toBe(BODY.subarray(10, 20).toString());
  });

  it("serves an open-ended range to the end of the file", async () => {
    const res = await request(app)
      .get("/api/documents/doc-range/view")
      .set({ ...auth(), Range: "bytes=990-" });

    expect(res.status).toBe(206);
    expect(res.headers["content-range"]).toBe(`bytes 990-999/${BODY.length}`);
    expect(res.body.toString()).toBe(BODY.subarray(990).toString());
  });

  it("serves a suffix range as the LAST n bytes", async () => {
    const res = await request(app)
      .get("/api/documents/doc-range/view")
      .set({ ...auth(), Range: "bytes=-20" });

    expect(res.status).toBe(206);
    expect(res.headers["content-range"]).toBe(`bytes 980-999/${BODY.length}`);
    expect(res.body.toString()).toBe(BODY.subarray(980).toString());
  });

  it("clamps an end beyond the file to the last byte", async () => {
    const res = await request(app)
      .get("/api/documents/doc-range/view")
      .set({ ...auth(), Range: "bytes=995-100000" });

    expect(res.status).toBe(206);
    expect(res.headers["content-range"]).toBe(`bytes 995-999/${BODY.length}`);
  });

  it("answers 416 when the range starts past the end", async () => {
    const res = await request(app)
      .get("/api/documents/doc-range/view")
      .set({ ...auth(), Range: "bytes=5000-6000" });

    expect(res.status).toBe(416);
    expect(res.headers["content-range"]).toBe(`bytes */${BODY.length}`);
  });

  it("answers 416 for an inverted range", async () => {
    const res = await request(app)
      .get("/api/documents/doc-range/view")
      .set({ ...auth(), Range: "bytes=500-100" });

    expect(res.status).toBe(416);
  });

  it("answers 416 for a malformed range rather than mis-serving bytes", async () => {
    for (const bad of ["bytes=abc-def", "bytes=-", "items=0-10", "bytes="]) {
      const res = await request(app)
        .get("/api/documents/doc-range/view")
        .set({ ...auth(), Range: bad });
      expect(res.status).toBe(416);
    }
  });

  it("still requires authorisation for a range request", async () => {
    const res = await request(app)
      .get("/api/documents/doc-range/view")
      .set({ Range: "bytes=0-10" });

    expect(res.status).toBe(401);
  });

  it("serves the view inline with the PDF content type", async () => {
    const res = await request(app).get("/api/documents/doc-range/view").set(auth());

    expect(res.headers["content-type"]).toMatch(/application\/pdf/);
    expect(res.headers["content-disposition"]).toMatch(/^inline/);
    expect(res.headers["content-disposition"]).toContain('filename="Big Document.pdf"');
  });

  it("reassembles to the original file across sequential ranges", async () => {
    const chunks = [];
    for (let start = 0; start < BODY.length; start += 250) {
      const end = Math.min(start + 249, BODY.length - 1);
      const res = await request(app)
        .get("/api/documents/doc-range/view")
        .set({ ...auth(), Range: `bytes=${start}-${end}` });
      expect(res.status).toBe(206);
      chunks.push(res.body);
    }

    expect(Buffer.concat(chunks).toString()).toBe(BODY.toString());
  });
});
