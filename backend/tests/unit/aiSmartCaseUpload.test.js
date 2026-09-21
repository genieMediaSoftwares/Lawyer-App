const fs = require("fs");
const os = require("os");
const path = require("path");

jest.mock("../../src/models/AiSmartCaseSession", () => ({
  findOne: jest.fn(async () => null),
  countDocuments: jest.fn(async () => 0),
  updateMany: jest.fn(async () => ({ modifiedCount: 0 })),
  create: jest.fn(async (data) => ({ _id: { toString: () => "session-1" }, ...data })),
}));
jest.mock("../../src/models/Document", () => ({
  create: jest.fn(async () => ({ _id: "doc-1" })),
}));
jest.mock("../../src/services/ai/aiSmartCasePipeline", () => ({
  PIPELINE_BUDGET_MS: 60000,
  AiSmartCasePipeline: jest.fn().mockImplementation(() => ({ run: jest.fn(async () => {}) })),
}));
jest.mock("../../src/services/document/pdfOptimizer", () => {
  const actual = jest.requireActual("../../src/services/document/pdfOptimizer");
  return { ...actual, optimizePdf: jest.fn() };
});

const controller = require("../../src/controllers/ai/aiSmartCaseController");
const pdfOptimizer = require("../../src/services/document/pdfOptimizer");
const preparedDocuments = require("../../src/services/ai/preparedDocuments");

const MB = 1024 * 1024;
const CLIENT = "64b7f0c2a1b2c3d4e5f60718";
const OTHER_CLIENT = "64b7f0c2a1b2c3d4e5f60719";
const leftovers = [];

const tempFile = (name, bytes, header = "%PDF-1.7\n") => {
  const file = path.join(os.tmpdir(), `${Date.now()}-${Math.random().toString(16).slice(2)}-${name}`);
  fs.writeFileSync(file, Buffer.concat([Buffer.from(header), Buffer.alloc(Math.max(bytes - header.length, 0))]));
  leftovers.push(file);
  return file;
};

const upload = (name, bytes, mimetype = "application/pdf") => ({
  path: tempFile(name, bytes),
  originalname: name,
  mimetype,
  size: bytes,
});

const makeRes = () => {
  const res = { statusCode: 200, body: null, headersSent: false };
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (payload) => {
    res.body = payload;
    res.headersSent = true;
    return res;
  };
  return res;
};

const call = async (method, req) => {
  const res = makeRes();
  let failure;
  await controller[method]({ get: () => "", app: { get: () => null }, ...req }, res, (e) => {
    failure = e;
  });
  if (failure) throw failure;
  return res;
};

afterAll(() => {
  for (const file of leftovers) fs.promises.unlink(file).catch(() => {});
});

describe("POST /ai/smart-case/optimize", () => {
  beforeEach(() => pdfOptimizer.optimizePdf.mockReset());

  test("stores the optimized PDF and returns a token with both sizes", async () => {
    const file = upload("fir.pdf", 8 * MB);
    const optimized = tempFile("opt.pdf", 2 * MB);
    pdfOptimizer.optimizePdf.mockResolvedValue({
      path: optimized,
      size: 2 * MB,
      originalSize: 8 * MB,
      optimized: true,
      passes: 1,
    });

    const res = await call("optimizeDocument", { user: { _id: CLIENT }, file });

    expect(res.statusCode).toBe(201);
    expect(res.body.data).toMatchObject({
      name: "fir.pdf",
      size: 2 * MB,
      originalSize: 8 * MB,
      optimized: true,
    });
    expect(res.body.data.token).toMatch(/^[a-f0-9]{32}$/);
    expect(fs.existsSync(file.path)).toBe(false);

    leftovers.push(path.join(preparedDocuments.PREPARED_DIR, `${CLIENT}-${res.body.data.token}.pdf`));
    leftovers.push(path.join(preparedDocuments.PREPARED_DIR, `${CLIENT}-${res.body.data.token}.json`));
  });

  test("refuses anything that is not a PDF, without altering it", async () => {
    const file = upload("notes.docx", 5 * MB, "application/vnd.openxmlformats-officedocument.wordprocessingml.document");

    const res = await call("optimizeDocument", { user: { _id: CLIENT }, file });

    expect(res.statusCode).toBe(415);
    expect(pdfOptimizer.optimizePdf).not.toHaveBeenCalled();
  });

  test("returns 422 with the reason when the PDF is still too large", async () => {
    const file = upload("scan.pdf", 15 * MB);
    pdfOptimizer.optimizePdf.mockRejectedValue(
      new pdfOptimizer.PdfOptimizationError("STILL_TOO_LARGE", "still over 3 MB")
    );

    const res = await call("optimizeDocument", { user: { _id: CLIENT }, file });

    expect(res.statusCode).toBe(422);
    expect(res.body.message).toBe("still over 3 MB");
    expect(fs.existsSync(file.path)).toBe(false);
  });

  test("returns 503 when the server cannot optimize PDFs", async () => {
    const file = upload("scan.pdf", 5 * MB);
    pdfOptimizer.optimizePdf.mockRejectedValue(
      new pdfOptimizer.PdfOptimizationError("UNAVAILABLE", "not available")
    );

    const res = await call("optimizeDocument", { user: { _id: CLIENT }, file });

    expect(res.statusCode).toBe(503);
  });
});

describe("POST /ai/smart-case/analyze", () => {
  test("refuses a document over 3 MB that skipped optimization", async () => {
    const big = upload("raw.pdf", 3 * MB + 1);

    const res = await call("analyzeSmartCase", {
      user: { _id: CLIENT },
      body: {},
      files: { documents: [big] },
    });

    expect(res.statusCode).toBe(413);
    expect(res.body.message).toMatch(/raw\.pdf is larger than 3 MB/);
    expect(fs.existsSync(big.path)).toBe(false);
  });

  test("accepts a document of exactly 3 MB as it is", async () => {
    const exact = upload("exact.pdf", 3 * MB);

    const res = await call("analyzeSmartCase", {
      user: { _id: CLIENT },
      body: {},
      files: { documents: [exact] },
    });

    expect(res.statusCode).toBe(202);
    expect(res.body.data.documentCount).toBe(1);
  });

  test("includes a prepared (optimized) PDF by its token", async () => {
    const source = tempFile("prepared.pdf", 2 * MB);
    const { token } = await preparedDocuments.save(CLIENT, source, {
      originalName: "big-fir.pdf",
      mimeType: "application/pdf",
    });

    const res = await call("analyzeSmartCase", {
      user: { _id: CLIENT },
      body: { preparedDocuments: token },
      files: { documents: [] },
    });

    expect(res.statusCode).toBe(202);
    expect(res.body.data.documentCount).toBe(1);
    const [doc] = res.body.data.uploadedDocuments;
    expect(doc.originalName).toBe("big-fir.pdf");
    leftovers.push(doc.path);
  });

  test("another client's token cannot be claimed", async () => {
    const source = tempFile("mine.pdf", MB);
    const { token } = await preparedDocuments.save(CLIENT, source, {
      originalName: "mine.pdf",
      mimeType: "application/pdf",
    });
    leftovers.push(path.join(preparedDocuments.PREPARED_DIR, `${CLIENT}-${token}.pdf`));
    leftovers.push(path.join(preparedDocuments.PREPARED_DIR, `${CLIENT}-${token}.json`));

    const res = await call("analyzeSmartCase", {
      user: { _id: OTHER_CLIENT },
      body: { preparedDocuments: [token] },
      files: { documents: [] },
    });

    expect(res.statusCode).toBe(410);
  });

  test("a refused analysis leaves the optimized PDF available for the retry", async () => {
    const AiSmartCaseSession = require("../../src/models/AiSmartCaseSession");
    const source = tempFile("retry.pdf", MB);
    const { token } = await preparedDocuments.save(CLIENT, source, {
      originalName: "retry.pdf",
      mimeType: "application/pdf",
    });

    AiSmartCaseSession.countDocuments.mockResolvedValueOnce(3);
    const busy = await call("analyzeSmartCase", {
      user: { _id: CLIENT },
      body: { preparedDocuments: [token] },
      files: { documents: [] },
    });
    expect(busy.statusCode).toBe(429);

    const retry = await call("analyzeSmartCase", {
      user: { _id: CLIENT },
      body: { preparedDocuments: [token] },
      files: { documents: [] },
    });
    expect(retry.statusCode).toBe(202);
    leftovers.push(retry.body.data.uploadedDocuments[0].path);
  });

  test("a malformed token is treated as expired", async () => {
    const res = await call("analyzeSmartCase", {
      user: { _id: CLIENT },
      body: { preparedDocuments: ["../../etc/passwd"] },
      files: { documents: [] },
    });

    expect(res.statusCode).toBe(410);
  });
});
