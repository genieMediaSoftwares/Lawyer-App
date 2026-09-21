/**
 * What a client gets when an upload path matches no file.
 *
 * Production showed users `Cannot GET /uploads/cases/<file>.pdf` — Express's
 * built-in finalhandler, as an HTML page. It is reached because
 * `express.static` calls next() when the file is not on disk, and nothing was
 * mounted after the routes to answer an unmatched path. The app's error
 * middleware does not catch it: a 4-argument handler only runs on next(err).
 *
 * Authorisation is NOT the cause — fileAuthMiddleware answers 401/404 as JSON
 * and never reaches the finalhandler. These pin the distinction.
 */
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.NODE_ENV = "test";

const fs = require("fs");
const path = require("path");
const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");

jest.mock("../../src/models/User");
jest.mock("../../src/models/Document");
jest.mock("../../src/models/Case");
jest.mock("../../src/models/Message");

const User = require("../../src/models/User");
const Document = require("../../src/models/Document");
const Case = require("../../src/models/Case");
const Message = require("../../src/models/Message");

const fileAuthMiddleware = require("../../src/middleware/fileAuthMiddleware");
const notFoundMiddleware = require("../../src/middleware/notFoundMiddleware");
const errorMiddleware = require("../../src/middleware/errorMiddleware");

const OWNER = "507f1f77bcf86cd799439011";
const UPLOADS = path.resolve(__dirname, "../../uploads");
const CASES = path.join(UPLOADS, "cases");

/** Mirrors app.js: static behind the file guard, then the 404 handler. */
function makeApp() {
  const app = express();
  app.use("/uploads", fileAuthMiddleware, express.static(UPLOADS, { index: false }));
  app.get("/api/ping", (req, res) => res.json({ success: true }));
  app.use(notFoundMiddleware);
  app.use(errorMiddleware);
  return app;
}

const token = () => jwt.sign({ id: OWNER }, process.env.JWT_SECRET, { expiresIn: "1h" });

let presentFile;

beforeEach(() => {
  jest.clearAllMocks();

  User.findById.mockImplementation((id) => ({
    select: async () => (id === OWNER ? { _id: id, role: "client" } : null),
  }));
  // The case references this filename, so the owner is entitled to read it.
  Case.find.mockReturnValue({ distinct: async () => [] });
  Document.findOne.mockResolvedValue(null);
  Message.findOne.mockReturnValue({ populate: async () => null });

  fs.mkdirSync(CASES, { recursive: true });
  presentFile = `present-${Date.now()}.pdf`;
  fs.writeFileSync(path.join(CASES, presentFile), "%PDF-1.4 real bytes");

  Case.findOne.mockReturnValue({
    select: async () => ({
      client: OWNER,
      assignedLawyer: null,
      selectedLawyer: null,
    }),
  });
});

afterEach(() => {
  try { fs.unlinkSync(path.join(CASES, presentFile)); } catch {}
});

describe("Missing upload files", () => {
  it("serves a case attachment that exists on disk", async () => {
    const res = await request(makeApp())
      .get(`/uploads/cases/${presentFile}?token=${token()}`);

    expect(res.status).toBe(200);
    expect(res.text || res.body.toString()).toContain("real bytes");
  });

  it("answers JSON, not 'Cannot GET', when the file is absent", async () => {
    // The exact production failure: authorised, but nothing on disk.
    const res = await request(makeApp())
      .get(`/uploads/cases/1789465124833-82df87498e995707.pdf?token=${token()}`);

    expect(res.status).toBe(404);
    expect(res.headers["content-type"]).toMatch(/application\/json/);
    expect(res.body.success).toBe(false);
    expect(res.body.code).toBe("NOT_FOUND");

    const body = JSON.stringify(res.body);
    expect(body).not.toMatch(/Cannot GET/);
    // The filesystem layout is ours, not the client's business.
    expect(body).not.toMatch(/uploads[/\\]cases/);
  });

  it("never leaks an absolute server path in the response", async () => {
    const res = await request(makeApp())
      .get(`/uploads/cases/missing.pdf?token=${token()}`);

    const body = JSON.stringify(res.body);
    expect(body).not.toMatch(/[A-Za-z]:\\/);   // windows path
    expect(body).not.toMatch(/\/home\//);       // ec2 path
    expect(body).not.toMatch(/node_modules/);
  });

  it("still refuses an unauthenticated request with 401, not 404", async () => {
    // Authorisation must be answered before existence, so a missing file and a
    // forbidden one stay distinguishable to us and opaque to a stranger.
    const res = await request(makeApp()).get("/uploads/cases/whatever.pdf");

    expect(res.status).toBe(401);
    expect(res.body.message).toMatch(/no token/i);
  });

  it("answers an unknown API route with JSON too", async () => {
    const res = await request(makeApp()).get("/api/does-not-exist");

    expect(res.status).toBe(404);
    expect(res.headers["content-type"]).toMatch(/application\/json/);
    expect(res.body.code).toBe("NOT_FOUND");
  });

  it("leaves real routes untouched", async () => {
    const res = await request(makeApp()).get("/api/ping");
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
