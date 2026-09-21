process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.NODE_ENV = "test";
process.env.BACKEND_URL = "http://localhost:5000";

const fs = require("fs");
const path = require("path");

const LAWYER = "507f1f77bcf86cd799439001";
const ENGAGED_CLIENT = "507f1f77bcf86cd799439002";
const STRANGER_CLIENT = "507f1f77bcf86cd799439003";
const OTHER_LAWYER = "507f1f77bcf86cd799439004";

const mockDocs = [];
const mockState = { nextId: 1 };

jest.mock("../../src/models/User");
jest.mock("../../src/models/Case");
jest.mock("../../src/models/Message");

jest.mock("../../src/models/Document", () => {
  const makeDoc = (data) => ({
    ...data,
    toObject() {
      const { toObject, save, ...rest } = this;
      return rest;
    },
    async save() {
      return this;
    },
  });

  const matches = (doc, query) => {
    if (query.$or) {
      return query.$or.some((clause) => matches(doc, clause));
    }
    if (query.clientId) {
      if (query.clientId.$in) {
        return query.clientId.$in.some((id) => String(id) === String(doc.clientId));
      }
      return String(query.clientId) === String(doc.clientId);
    }
    return true;
  };

  return {
    __makeDoc: makeDoc,
    __push: (d) => mockDocs.push(d),
    create: async (data) => {
      const doc = makeDoc({ _id: `doc-${mockState.nextId++}`, name: "", ...data });
      mockDocs.push(doc);
      return doc;
    },
    findById: async (id) => mockDocs.find((d) => String(d._id) === String(id)) || null,
    findByIdAndDelete: async (id) => {
      const i = mockDocs.findIndex((d) => String(d._id) === String(id));
      return i >= 0 ? mockDocs.splice(i, 1)[0] : null;
    },
    findOne: async () => null,
    find: (query) => ({
      sort: async () => mockDocs.filter((d) => matches(d, query)),
    }),
  };
});

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
app.use((err, req, res, _next) => {
  res.status(err.status || 500).json({ success: false, message: err.message });
});

const auth = (id) => ({
  Authorization: `Bearer ${jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: "1h" })}`,
});

const UPLOAD_DIR = path.resolve(__dirname, "../../uploads/acknowledgements");

const seed = (ownerId, overrides = {}) => {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  const fileName = `lawyer-${mockState.nextId++}-${Date.now()}.pdf`;
  fs.writeFileSync(path.join(UPLOAD_DIR, fileName), "%PDF-1.4 bytes");

  const doc = Document.__makeDoc({
    _id: `doc-${mockState.nextId++}`,
    clientId: ownerId,
    originalName: "brief.pdf",
    name: "",
    fileName,
    filePath: `uploads/acknowledgements/${fileName}`,
    mimeType: "application/pdf",
    fileSize: 14,
    uploadedAt: new Date(),
    ...overrides,
  });
  Document.__push(doc);
  return doc;
};

const ROLES = {
  [LAWYER]: "lawyer",
  [OTHER_LAWYER]: "lawyer",
  [ENGAGED_CLIENT]: "client",
  [STRANGER_CLIENT]: "client",
};

beforeEach(() => {
  jest.clearAllMocks();
  mockDocs.length = 0;

  User.findById.mockImplementation((id) => ({
    select: async () => (ROLES[id] ? { _id: id, role: ROLES[id] } : null),
  }));

  Case.find.mockImplementation((query) => ({
    distinct: async () => {
      const forLawyer = JSON.stringify(query).includes(LAWYER);
      return forLawyer ? [ENGAGED_CLIENT] : [];
    },
  }));
  Case.exists.mockResolvedValue(false);
});

afterEach(() => {
  for (const d of mockDocs) {
    try { fs.unlinkSync(path.resolve(__dirname, "../..", d.filePath)); } catch {}
  }
});

describe("Lawyer document listing", () => {
  it("lists the lawyer's OWN uploaded documents", async () => {
    seed(LAWYER, { originalName: "my_own_brief.pdf" });

    const res = await request(app).get("/api/documents").set(auth(LAWYER));

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].originalName).toBe("my_own_brief.pdf");
  });

  it("lists documents of a client the lawyer is engaged with", async () => {
    seed(ENGAGED_CLIENT, { originalName: "client_evidence.pdf" });

    const res = await request(app).get("/api/documents").set(auth(LAWYER));

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
  });

  it("lists own uploads and engaged clients' documents together", async () => {
    seed(LAWYER, { originalName: "mine.pdf" });
    seed(ENGAGED_CLIENT, { originalName: "theirs.pdf" });
    seed(STRANGER_CLIENT, { originalName: "not_mine.pdf" });

    const res = await request(app).get("/api/documents").set(auth(LAWYER));

    const names = res.body.data.map((d) => d.originalName).sort();
    expect(names).toEqual(["mine.pdf", "theirs.pdf"]);
  });

  it("never lists a document of a client the lawyer is not engaged with", async () => {
    seed(STRANGER_CLIENT);

    const res = await request(app).get("/api/documents").set(auth(LAWYER));
    expect(res.body.data).toHaveLength(0);
  });

  it("does not leak one lawyer's own uploads to another lawyer", async () => {
    seed(LAWYER, { originalName: "private_strategy.pdf" });

    const res = await request(app).get("/api/documents").set(auth(OTHER_LAWYER));
    expect(res.body.data).toHaveLength(0);
  });
});

describe("Lawyer view and download", () => {
  it("opens the lawyer's own document", async () => {
    const doc = seed(LAWYER);

    const view = await request(app)
      .get(`/api/documents/${doc._id}/view`)
      .set(auth(LAWYER));

    expect(view.status).toBe(200);
    expect(view.headers["content-type"]).toMatch(/application\/pdf/);
    expect(view.headers["content-disposition"]).toMatch(/^inline/);
  });

  it("opens an engaged client's document", async () => {
    const doc = seed(ENGAGED_CLIENT);

    const view = await request(app)
      .get(`/api/documents/${doc._id}/view`)
      .set(auth(LAWYER));

    expect(view.status).toBe(200);
  });

  it("refuses a document belonging to an unrelated client", async () => {
    const doc = seed(STRANGER_CLIENT);

    expect(
      (await request(app).get(`/api/documents/${doc._id}/view`).set(auth(LAWYER))).status
    ).toBe(404);
    expect(
      (await request(app).get(`/api/documents/${doc._id}/download`).set(auth(LAWYER))).status
    ).toBe(404);
  });

  it("refuses another lawyer's own document", async () => {
    const doc = seed(LAWYER);

    const res = await request(app)
      .get(`/api/documents/${doc._id}/view`)
      .set(auth(OTHER_LAWYER));

    expect(res.status).toBe(404);
  });

  it("downloads the lawyer's own document under its display name", async () => {
    const doc = seed(LAWYER, { name: "Final Brief.pdf" });

    const res = await request(app)
      .get(`/api/documents/${doc._id}/download`)
      .set(auth(LAWYER));

    expect(res.status).toBe(200);
    expect(res.headers["content-disposition"]).toMatch(/^attachment/);
    expect(res.headers["content-disposition"]).toContain('filename="Final Brief.pdf"');
  });
});

describe("Lawyer rename, replace and delete permissions", () => {
  it("renames the lawyer's own document", async () => {
    const doc = seed(LAWYER);

    const res = await request(app)
      .patch(`/api/documents/${doc._id}`)
      .set(auth(LAWYER))
      .send({ name: "Case Strategy" });

    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe("Case Strategy.pdf");
  });

  it("does NOT let a lawyer rename an engaged client's document", async () => {
    const doc = seed(ENGAGED_CLIENT);

    const res = await request(app)
      .patch(`/api/documents/${doc._id}`)
      .set(auth(LAWYER))
      .send({ name: "Renamed By Lawyer" });

    expect(res.status).toBe(404);
    expect(mockDocs[0].name).toBe("");
  });

  it("replaces the lawyer's own document, keeping its id", async () => {
    const doc = seed(LAWYER);

    const res = await request(app)
      .post(`/api/documents/${doc._id}/replace`)
      .set(auth(LAWYER))
      .attach("acknowledgement", Buffer.from("%PDF-1.4 NEW"), "new.pdf");

    expect(res.status).toBe(200);
    expect(res.body.data._id).toBe(doc._id);
    expect(res.body.data.clientId).toBe(LAWYER);
  });

  it("does NOT let a lawyer replace an engaged client's document", async () => {
    const doc = seed(ENGAGED_CLIENT);
    const before = fs.readFileSync(path.resolve(__dirname, "../..", doc.filePath), "utf8");

    const res = await request(app)
      .post(`/api/documents/${doc._id}/replace`)
      .set(auth(LAWYER))
      .attach("acknowledgement", Buffer.from("%PDF-1.4 NEW"), "new.pdf");

    expect(res.status).toBe(404);
    expect(fs.readFileSync(path.resolve(__dirname, "../..", doc.filePath), "utf8")).toBe(before);
  });

  it("deletes the lawyer's own document", async () => {
    const doc = seed(LAWYER);

    const res = await request(app)
      .delete(`/api/documents/${doc._id}`)
      .set(auth(LAWYER));

    expect(res.status).toBe(200);
  });

  it("does NOT let a lawyer delete an engaged client's document", async () => {
    const doc = seed(ENGAGED_CLIENT);

    const res = await request(app)
      .delete(`/api/documents/${doc._id}`)
      .set(auth(LAWYER));

    expect(res.status).toBe(403);
    expect(mockDocs.find((d) => d._id === doc._id)).toBeDefined();
  });

  it("requires authentication for every lawyer document route", async () => {
    const doc = seed(LAWYER);

    expect((await request(app).get("/api/documents")).status).toBe(401);
    expect((await request(app).get(`/api/documents/${doc._id}/view`)).status).toBe(401);
    expect((await request(app).patch(`/api/documents/${doc._id}`).send({ name: "x" })).status).toBe(401);
    expect((await request(app).delete(`/api/documents/${doc._id}`)).status).toBe(401);
  });
});
