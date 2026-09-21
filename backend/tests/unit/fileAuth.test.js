const jwt = require("jsonwebtoken");
const express = require("express");
const request = require("supertest");

jest.mock("../../src/models/User");
jest.mock("../../src/models/Document");
jest.mock("../../src/models/Case");
jest.mock("../../src/models/Message");

const User = require("../../src/models/User");
const Document = require("../../src/models/Document");
const Case = require("../../src/models/Case");
const Message = require("../../src/models/Message");

const fileAuthMiddleware = require("../../src/middleware/fileAuthMiddleware");

const SECRET = "test-secret-for-file-auth";
const OWNER_ID = "507f1f77bcf86cd799439011";
const OTHER_ID = "507f1f77bcf86cd799439022";

function makeApp() {
  const app = express();
  app.use("/uploads", fileAuthMiddleware, (req, res) =>
    res.status(200).send("FILE-BYTES")
  );
  return app;
}

const tokenFor = (id, opts = {}) =>
  jwt.sign({ id }, SECRET, { expiresIn: "7d", ...opts });

beforeEach(() => {
  jest.clearAllMocks();
  process.env.JWT_SECRET = SECRET;

  User.findById.mockImplementation((id) => ({
    select: async () => (id === OWNER_ID || id === OTHER_ID ? { _id: id, role: "client" } : null),
  }));

  Document.findOne.mockResolvedValue({ clientId: OWNER_ID });
  Case.findOne.mockReturnValue({ select: async () => null });
  Case.exists.mockResolvedValue(false);
  Message.findOne.mockReturnValue({ populate: async () => null });
});

describe("fileAuthMiddleware", () => {
  it("serves the file to its owner with a single valid token", async () => {
    const res = await request(makeApp()).get(
      `/uploads/documents/a.pdf?token=${tokenFor(OWNER_ID)}`
    );
    expect(res.status).toBe(200);
    expect(res.text).toBe("FILE-BYTES");
  });

  it("serves the file when the token arrives as a Bearer header", async () => {
    const res = await request(makeApp())
      .get("/uploads/documents/a.pdf")
      .set("Authorization", `Bearer ${tokenFor(OWNER_ID)}`);
    expect(res.status).toBe(200);
  });

  it("accepts a stale token followed by a current one", async () => {
    const stale = tokenFor(OWNER_ID, { expiresIn: "-1h" });
    const res = await request(makeApp()).get(
      `/uploads/documents/a.pdf?token=${stale}&token=${tokenFor(OWNER_ID)}`
    );
    expect(res.status).toBe(200);
    expect(res.text).toBe("FILE-BYTES");
  });

  it("rejects a genuinely expired token", async () => {
    const res = await request(makeApp()).get(
      `/uploads/documents/a.pdf?token=${tokenFor(OWNER_ID, { expiresIn: "-1h" })}`
    );
    expect(res.status).toBe(401);
    expect(res.body.message).toMatch(/Invalid or expired token/);
  });

  it("rejects a token signed with the wrong secret", async () => {
    const forged = jwt.sign({ id: OWNER_ID }, "not-the-secret");
    const res = await request(makeApp()).get(`/uploads/documents/a.pdf?token=${forged}`);
    expect(res.status).toBe(401);
  });

  it("refuses a request with no token at all", async () => {
    const res = await request(makeApp()).get("/uploads/documents/a.pdf");
    expect(res.status).toBe(401);
    expect(res.body.message).toMatch(/No token provided/);
  });

  it("does not let one user read another user's document", async () => {
    const res = await request(makeApp()).get(
      `/uploads/documents/a.pdf?token=${tokenFor(OTHER_ID)}`
    );
    expect(res.status).toBe(404);
    expect(res.text).not.toContain("FILE-BYTES");
  });

  it("serves a public profile image without any token", async () => {
    const res = await request(makeApp()).get("/uploads/profiles/pic.jpg");
    expect(res.status).toBe(200);
  });

  it.each(["a.pdf", "a.docx", "a.doc", "a.jpg", "a.png", "a.txt"])(
    "serves %s to its owner",
    async (name) => {
      const res = await request(makeApp()).get(
        `/uploads/documents/${name}?token=${tokenFor(OWNER_ID)}`
      );
      expect(res.status).toBe(200);
    }
  );
});
