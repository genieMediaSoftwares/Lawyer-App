const fs = require("fs");
const os = require("os");
const path = require("path");

jest.mock("child_process", () => ({ execFile: jest.fn() }));
const { execFile } = require("child_process");

const {
  optimizePdf,
  resetGhostscriptCache,
  PdfOptimizationError,
} = require("../../src/services/document/pdfOptimizer");

const MB = 1024 * 1024;
const created = [];

const writePdf = (bytes, header = "%PDF-1.7\n") => {
  const file = path.join(os.tmpdir(), `in-${Date.now()}-${Math.random().toString(16).slice(2)}.pdf`);
  const body = Buffer.alloc(Math.max(bytes - header.length, 0), 0x20);
  fs.writeFileSync(file, Buffer.concat([Buffer.from(header, "latin1"), body]));
  created.push(file);
  return file;
};

const outputOf = (args) =>
  args.find((a) => a.startsWith("-sOutputFile=")).slice("-sOutputFile=".length);

// Ghostscript stand-in: the version probe succeeds; each pass writes a PDF
// of the next size in `sizes` (null = the pass fails).
const fakeGhostscript = (sizes) => {
  const queue = [...sizes];
  execFile.mockImplementation((binary, args, options, callback) => {
    if (args[0] === "--version") return callback(null, "10.03.1");
    const size = queue.shift();
    if (size === null || size === undefined) return callback(new Error("gs failed"));
    const out = outputOf(args);
    fs.writeFileSync(out, Buffer.concat([Buffer.from("%PDF-1.5\n"), Buffer.alloc(size - 9, 0x20)]));
    created.push(out);
    return callback(null, "");
  });
};

beforeEach(() => {
  execFile.mockReset();
  resetGhostscriptCache();
});

afterAll(() => {
  for (const file of created) {
    try {
      fs.unlinkSync(file);
    } catch {
      // Already moved or removed.
    }
  }
});

describe("pdfOptimizer", () => {
  test("a PDF already within 3 MB is returned untouched, without running Ghostscript", async () => {
    const input = writePdf(2 * MB);

    const result = await optimizePdf(input, { targetBytes: 3 * MB });

    expect(result).toMatchObject({ path: input, optimized: false, passes: 0 });
    expect(execFile).not.toHaveBeenCalled();
  });

  test("a large PDF that fits after the first pass stops there", async () => {
    const input = writePdf(8 * MB);
    fakeGhostscript([2 * MB]);

    const result = await optimizePdf(input, { targetBytes: 3 * MB });

    expect(result.optimized).toBe(true);
    expect(result.passes).toBe(1);
    expect(result.size).toBe(2 * MB);
    expect(result.originalSize).toBe(8 * MB);
    expect(result.path).not.toBe(input);
  });

  test("runs a stronger second pass when the first is not enough", async () => {
    const input = writePdf(9 * MB);
    fakeGhostscript([4 * MB, 2.5 * MB]);

    const result = await optimizePdf(input, { targetBytes: 3 * MB });

    expect(result.passes).toBe(2);
    expect(result.size).toBe(2.5 * MB);
    const passArgs = execFile.mock.calls.filter((c) => c[1][0] !== "--version").map((c) => c[1]);
    expect(passArgs[0]).toContain("-dColorImageResolution=150");
    expect(passArgs[1]).toContain("-dColorImageResolution=110");
    for (const args of passArgs) {
      expect(args).toContain("-dSAFER");
      expect(args).toContain("-dMonoImageResolution=300");
    }
  });

  test("rejects when still over the limit after every pass", async () => {
    const input = writePdf(12 * MB);
    fakeGhostscript([6 * MB, 4 * MB]);

    await expect(optimizePdf(input, { targetBytes: 3 * MB })).rejects.toMatchObject({
      code: "STILL_TOO_LARGE",
      bestSize: 4 * MB,
    });
  });

  test("reports unavailable when Ghostscript is not installed", async () => {
    const input = writePdf(5 * MB);
    execFile.mockImplementation((binary, args, options, callback) => callback(new Error("ENOENT")));

    const error = await optimizePdf(input, { targetBytes: 3 * MB }).catch((e) => e);

    expect(error).toBeInstanceOf(PdfOptimizationError);
    expect(error.code).toBe("UNAVAILABLE");
  });

  test("a PDF Ghostscript cannot process is rejected as failed", async () => {
    const input = writePdf(5 * MB);
    fakeGhostscript([null, null]);

    await expect(optimizePdf(input, { targetBytes: 3 * MB })).rejects.toMatchObject({
      code: "FAILED",
    });
  });

  test("a file that is not a PDF is refused before any processing", async () => {
    const input = writePdf(5 * MB, "PK");

    await expect(optimizePdf(input, { targetBytes: 3 * MB })).rejects.toMatchObject({
      code: "INVALID_PDF",
    });
    expect(execFile).not.toHaveBeenCalled();
  });
});
