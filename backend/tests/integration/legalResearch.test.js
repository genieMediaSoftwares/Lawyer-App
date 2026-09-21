const fs = require("fs");
const path = require("path");
const request = require("supertest");
const mongoose = require("mongoose");
const jwt = require("jsonwebtoken");

const TEST_MONGO_URI = process.env.TEST_MONGO_URI;
const describeWithDb = TEST_MONGO_URI ? describe : describe.skip;

process.env.JWT_SECRET = process.env.JWT_SECRET || "legal-research-test-secret";
process.env.GEMINI_API_KEY = process.env.GEMINI_API_KEY || "test-key-not-real";

jest.mock("../../src/services/ai/geminiClient", () => ({
  generate: jest.fn(),
  generateWithSearch: jest.fn(),
  isConfigured: true,
  DEFAULT_MODELS: ["test-model"],
}));

const gemini = require("../../src/services/ai/geminiClient");
const app = require("../../src/app");
const Case = require("../../src/models/Case");
const User = require("../../src/models/User");
const AiConversation = require("../../src/models/AiConversation");
const { groundCaseResults } = require("../../src/services/ai/legalResearchService");

const UPLOAD_DIR = path.resolve(__dirname, "../../uploads/test-legal-research");
const FILE_TEXT = "Petition for divorce by mutual consent. The parties have lived separately since 2021.";

const tokenFor = (user) =>
  jwt.sign({ id: user._id.toString(), role: user.role }, process.env.JWT_SECRET, { expiresIn: "15m" });
const as = (user) => ({ Authorization: `Bearer ${tokenFor(user)}` });

let counter = 0;
const makeUser = (role) => {
  counter += 1;
  return User.create({
    fullName: `${role} ${counter}`,
    email: `${role}${counter}-${Date.now()}@example.test`,
    mobile: `8${String(counter).padStart(9, "0")}`,
    password: "Password123",
    role,
  });
};

const waitFor = async (id, done) => {
  for (let i = 0; i < 100; i += 1) {
    const doc = await AiConversation.findById(id).lean();
    if (done(doc)) return doc;
    await new Promise((r) => setTimeout(r, 20));
  }
  throw new Error("timed out waiting for research");
};

describeWithDb("Legal research on an existing case", () => {
  let lawyer;
  let otherLawyer;
  let client;
  let caseItem;
  let docIds;

  beforeAll(async () => {
    await mongoose.connect(TEST_MONGO_URI);
    if (!/test/i.test(mongoose.connection.name)) {
      throw new Error("TEST_MONGO_URI must point at a database whose name contains 'test'.");
    }
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
    fs.writeFileSync(path.join(UPLOAD_DIR, "petition.txt"), FILE_TEXT);
    fs.writeFileSync(path.join(UPLOAD_DIR, "archive.zip"), "zip");
  });

  beforeEach(async () => {
    jest.clearAllMocks();
    await Promise.all([Case.deleteMany({}), User.deleteMany({}), AiConversation.deleteMany({})]);
    client = await makeUser("client");
    lawyer = await makeUser("lawyer");
    otherLawyer = await makeUser("lawyer");

    caseItem = await Case.create({
      client: client._id,
      title: "Mutual consent divorce",
      description: "Joint petition",
      category: "Family Law",
      location: "Hyderabad",
      assignedLawyer: lawyer._id,
      selectedLawyer: lawyer._id,
      status: "Accepted",
      documents: [
        { name: "petition.txt", url: "http://localhost:5000/uploads/test-legal-research/petition.txt", size: "90" },
        { name: "archive.zip", url: "uploads/test-legal-research/archive.zip", size: "3" },
        { name: "gone.pdf", url: "uploads/test-legal-research/gone.pdf", size: "10" },
      ],
    });
    docIds = caseItem.documents.map((d) => String(d._id));

    gemini.generate.mockResolvedValue({ text: "### Issue\nWhether the separation period is met [D1].", model: "test" });
  });

  afterAll(async () => {
    fs.rmSync(UPLOAD_DIR, { recursive: true, force: true });
    if (mongoose.connection.readyState === 1) {
      await mongoose.connection.dropDatabase();
      await mongoose.disconnect();
    }
  });

  const startResearch = (user, body) =>
    request(app).post("/api/ai/research/sessions").set(as(user)).send(body);

  it("lists only the cases the lawyer is engaged on", async () => {
    await Case.create({
      client: client._id, title: "Someone else's matter", description: "x", category: "Civil", location: "X",
      assignedLawyer: otherLawyer._id, status: "Accepted",
    });

    const res = await request(app).get("/api/ai/research/cases").set(as(lawyer));

    expect(res.status).toBe(200);
    expect(res.body.data.map((c) => c.title)).toEqual(["Mutual consent divorce"]);
    expect(res.body.data[0].documentCount).toBe(3);
  });

  it("lists the case's documents with honest availability", async () => {
    const res = await request(app).get(`/api/ai/research/cases/${caseItem._id}/documents`).set(as(lawyer));

    expect(res.status).toBe(200);
    const byName = Object.fromEntries(res.body.data.documents.map((d) => [d.name, d]));
    expect(byName["petition.txt"]).toMatchObject({ status: "available", selectable: true, type: "TXT" });
    expect(byName["archive.zip"]).toMatchObject({ status: "unsupported", selectable: false });
    expect(byName["gone.pdf"]).toMatchObject({ status: "missing", selectable: false });
    expect(JSON.stringify(res.body)).not.toContain(path.resolve(__dirname, "../.."));
  });

  it("refuses another lawyer's case and its documents", async () => {
    const docs = await request(app).get(`/api/ai/research/cases/${caseItem._id}/documents`).set(as(otherLawyer));
    const start = await startResearch(otherLawyer, { caseId: caseItem._id, documentIds: [docIds[0]] });

    expect(docs.status).toBe(404);
    expect(start.status).toBe(404);
    expect(gemini.generate).not.toHaveBeenCalled();
  });

  it("refuses clients", async () => {
    const res = await request(app).get("/api/ai/research/cases").set(as(client));
    expect(res.status).toBe(403);
  });

  it("rejects a document id from a different case", async () => {
    const other = await Case.create({
      client: client._id, title: "Other", description: "x", category: "Civil", location: "X",
      assignedLawyer: lawyer._id, status: "Accepted",
      documents: [{ name: "secret.txt", url: "uploads/test-legal-research/petition.txt" }],
    });

    const res = await startResearch(lawyer, { caseId: caseItem._id, documentIds: [String(other.documents[0]._id)] });

    expect(res.status).toBe(403);
    expect(await AiConversation.countDocuments()).toBe(0);
  });

  it("explains why an unsupported or missing document cannot be analysed", async () => {
    const res = await startResearch(lawyer, { caseId: caseItem._id, documentIds: [docIds[1], docIds[2]] });

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/archive\.zip/);
    expect(res.body.message).toMatch(/gone\.pdf/);
  });

  it("reads the selected document, grounds the research in it, and restores the session", async () => {
    const res = await startResearch(lawyer, {
      caseId: caseItem._id,
      documentIds: [docIds[0]],
      question: "Is the one-year separation requirement met?",
      jurisdiction: "India",
    });

    expect(res.status).toBe(202);
    const id = res.body.data.conversationId;
    const done = await waitFor(id, (d) => d.researchStatus !== "processing");

    expect(done.researchStatus).toBe("completed");
    const [parts, options] = gemini.generate.mock.calls[0];
    expect(parts[0].text).toContain(FILE_TEXT);
    expect(parts[0].text).toContain('<document ref="D1" name="petition.txt">');
    expect(parts[0].text).toContain("Is the one-year separation requirement met?");
    expect(options.systemInstruction).toMatch(/Never invent page numbers/);

    const restored = await request(app).get(`/api/ai/conversations/${id}`).set(as(lawyer));
    const conversation = restored.body.data.conversation;
    expect(conversation.caseTitle).toBe("Mutual consent divorce");
    expect(conversation.researchDocuments[0]).toMatchObject({ name: "petition.txt", reference: "D1", status: "used" });
    expect(conversation.messages.map((m) => m.role)).toEqual(["user", "model"]);
    expect(conversation).not.toHaveProperty("documentContext");

    const stranger = await request(app).get(`/api/ai/conversations/${id}`).set(as(otherLawyer));
    expect(stranger.status).toBe(404);
  });

  it("marks the research failed, without inventing an answer, when the model is unavailable", async () => {
    gemini.generate.mockResolvedValue({ text: null, error: "HTTP 503" });

    const res = await startResearch(lawyer, { caseId: caseItem._id, documentIds: [docIds[0]] });
    const done = await waitFor(res.body.data.conversationId, (d) => d.researchStatus !== "processing");

    expect(done.researchStatus).toBe("failed");
    expect(done.researchError).not.toMatch(/503/);
    expect(done.messages).toHaveLength(1);
  });

  describe("follow-up chat", () => {
    const realFetch = global.fetch;
    afterEach(() => {
      global.fetch = realFetch;
    });

    it("sends this session's documents and not another session's", async () => {
      const first = await startResearch(lawyer, { caseId: caseItem._id, documentIds: [docIds[0]] });
      const id = first.body.data.conversationId;
      await waitFor(id, (d) => d.researchStatus !== "processing");

      const unrelated = await AiConversation.create({
        userId: lawyer._id, mode: "research", title: "Unrelated",
        messages: [{ role: "user", text: "Unrelated question" }],
      });

      let sent;
      global.fetch = jest.fn(async (url, init) => {
        sent = JSON.parse(init.body);
        return { ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: "Answer" }] } }] }) };
      });

      const res = await request(app)
        .post("/api/ai/chat")
        .set(as(lawyer))
        .send({ message: "Which documents support the separation?", conversationId: id, mode: "research" });

      expect(res.status).toBe(200);
      const system = sent.systemInstruction.parts[0].text;
      expect(system).toContain(FILE_TEXT);
      expect(system).toContain("Mutual consent divorce");
      expect(JSON.stringify(sent)).not.toContain("Unrelated question");
      expect(unrelated).toBeDefined();
    });

    it("refuses a follow-up while the research is still running", async () => {
      gemini.generate.mockReturnValue(new Promise(() => {}));
      const first = await startResearch(lawyer, { caseId: caseItem._id, documentIds: [docIds[0]] });

      const res = await request(app)
        .post("/api/ai/chat")
        .set(as(lawyer))
        .send({ message: "Next?", conversationId: first.body.data.conversationId, mode: "research" });

      expect(res.status).toBe(409);
    });
  });

  describe("relevant cases", () => {
    const completedSession = async () => {
      const res = await startResearch(lawyer, { caseId: caseItem._id, documentIds: [docIds[0]] });
      const id = res.body.data.conversationId;
      await waitFor(id, (d) => d.researchStatus !== "processing");
      return id;
    };

    const search = (id, user = lawyer, body = {}) =>
      request(app).post(`/api/ai/research/${id}/relevant-cases`).set(as(user)).send(body);

    it("shows a failure and no results when the search provider fails", async () => {
      gemini.generateWithSearch.mockResolvedValue({ text: null, sources: [], supports: [], error: "HTTP 500" });
      const id = await completedSession();

      const res = await search(id);
      const done = await waitFor(id, (d) => d.relevantCases.status !== "searching");

      expect(res.status).toBe(202);
      expect(done.relevantCases.status).toBe("failed");
      expect(done.relevantCases.results).toEqual([]);
      expect(done.relevantCases.message).toMatch(/could not be completed/);
    });

    it("keeps only decisions backed by a retrieved source", async () => {
      const text = '```json\n[{"caseTitle":"Amardeep Singh v Harveen Kaur","citation":"(2017) 8 SCC 746","court":"Supreme Court of India","decisionDate":"2017-09-12","relevance":"Waiver of the cooling-off period","principle":""},{"caseTitle":"Invented v Nobody","citation":"","court":"","decisionDate":"","relevance":"x","principle":""}]\n```';
      gemini.generateWithSearch.mockResolvedValue({
        text,
        sources: [{ uri: "https://indiankanoon.org/doc/1/", title: "indiankanoon.org" }],
        supports: [{ text: '"caseTitle":"Amardeep Singh v Harveen Kaur"', sourceIndices: [0] }],
        error: null,
      });
      const id = await completedSession();

      await search(id, lawyer, { query: "Supreme Court only", jurisdiction: "India" });
      const done = await waitFor(id, (d) => d.relevantCases.status !== "searching");

      expect(done.relevantCases.status).toBe("completed");
      expect(done.relevantCases.results).toHaveLength(1);
      expect(done.relevantCases.results[0]).toMatchObject({
        caseTitle: "Amardeep Singh v Harveen Kaur",
        verificationStatus: "Source Retrieved",
        sources: [{ url: "https://indiankanoon.org/doc/1/", name: "indiankanoon.org" }],
      });
      expect(gemini.generateWithSearch.mock.calls[0][0]).toContain("Supreme Court only");
    });

    it("refuses a search on someone else's session and before any research exists", async () => {
      const id = await completedSession();
      const empty = await AiConversation.create({
        userId: lawyer._id, mode: "research", title: "Empty", messages: [{ role: "user", text: "q" }],
      });

      expect((await search(id, otherLawyer)).status).toBe(404);
      expect((await search(empty._id)).status).toBe(400);
    });

    it("does not start a second search while one is running", async () => {
      gemini.generateWithSearch.mockReturnValue(new Promise(() => {}));
      const id = await completedSession();

      const [a, b] = await Promise.all([search(id), search(id)]);

      expect([a.status, b.status].sort()).toEqual([202, 409]);
    });
  });
});

describe("groundCaseResults", () => {
  it("labels non-official sources as not yet verified", () => {
    const results = groundCaseResults(
      '[{"caseTitle":"A v B","citation":"","court":"High Court","decisionDate":"","relevance":"r","principle":""}]',
      [{ uri: "https://example-blog.com/a-v-b", title: "example-blog.com" }],
      [{ text: "A v B", sourceIndices: [0] }]
    );
    expect(results).toHaveLength(1);
    expect(results[0].verificationStatus).toBe("Search Result — Not Yet Verified");
  });

  it("returns nothing for text that is not a JSON array", () => {
    expect(groundCaseResults("I could not find anything.", [], [])).toEqual([]);
  });
});
