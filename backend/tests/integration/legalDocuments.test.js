process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";
process.env.NODE_ENV = "test";

const mockDocuments = [];
const mockAcceptances = [];

const oid = (value) => ({
  toString: () => value,
  toJSON: () => value,
  _bsontype: "ObjectId",
});

const matches = (doc, query) => {
  if (query.type && doc.type !== query.type) return false;
  if (query.version && doc.version !== query.version) return false;
  if (query.isActive !== undefined && doc.isActive !== query.isActive) return false;
  if (query.requiresAcceptance !== undefined && doc.requiresAcceptance !== query.requiresAcceptance) {
    return false;
  }
  if (query.audience && query.audience.$in && !query.audience.$in.includes(doc.audience)) {
    return false;
  }
  return true;
};

jest.mock("../../src/models/LegalDocument", () => {
  const model = {
    find: (query) => {
      const results = mockDocuments.filter((doc) => matches(doc, query));
      const chain = {
        select: () => chain,
        sort: async () => results,
        then: (resolve) => resolve(results),
      };
      return chain;
    },
    findOne: (query) => {
      const result = mockDocuments.find((doc) => matches(doc, query)) || null;
      const chain = {
        select: async () => result,
        then: (resolve) => resolve(result),
      };
      return chain;
    },
  };
  model.LEGAL_DOCUMENT_TYPES = ["platform_terms", "client_terms", "privacy_policy"];
  model.AUDIENCES = ["all", "client", "lawyer"];
  return model;
});

jest.mock("../../src/models/LegalAcceptance", () => ({
  find: (query) => {
    const results = mockAcceptances.filter(
      (record) =>
        String(record.user) === String(query.user) &&
        (!query.documentType ||
          !query.documentType.$in ||
          query.documentType.$in.includes(record.documentType))
    );
    const chain = {
      select: () => chain,
      sort: async () => results,
      then: (resolve) => resolve(results),
    };
    return chain;
  },
  findOne: async (query) =>
    mockAcceptances.find(
      (record) =>
        String(record.user) === String(query.user) &&
        record.documentType === query.documentType &&
        record.version === query.version
    ) || null,
  create: async (doc) => {
    const record = { ...doc, _id: oid(`acc-${mockAcceptances.length + 1}`) };
    mockAcceptances.push(record);
    return record;
  },
}));

const legalController = require("../../src/controllers/legal/legalController");

const USER = oid("user-1");

const makeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (payload) => {
    res.body = payload;
    return res;
  };
  return res;
};

const call = async (handler, req) => {
  const res = makeRes();
  await legalController[handler](
    { params: {}, body: {}, query: {}, ...req },
    res,
    (err) => {
      throw err;
    }
  );
  return res;
};

beforeEach(() => {
  mockDocuments.length = 0;
  mockAcceptances.length = 0;
  mockDocuments.push(
    {
      _id: oid("doc-terms-1"),
      type: "client_terms",
      version: "1.0",
      title: "Client Terms",
      content: "...",
      audience: "client",
      isActive: true,
      requiresAcceptance: true,
    },
    {
      _id: oid("doc-terms-old"),
      type: "client_terms",
      version: "0.9",
      title: "Client Terms",
      content: "...",
      audience: "client",
      isActive: false,
      requiresAcceptance: true,
    },
    {
      _id: oid("doc-lawyer"),
      type: "platform_terms",
      version: "1.0",
      title: "Advocate Terms",
      content: "...",
      audience: "lawyer",
      isActive: true,
      requiresAcceptance: true,
    }
  );
});

describe("GET /legal/documents/:type", () => {
  it("returns the active version", async () => {
    const res = await call("getByType", { params: { type: "client_terms" } });

    expect(res.statusCode).toBe(200);
    expect(res.body.data.version).toBe("1.0");
  });

  it("rejects an unknown document type", async () => {
    const res = await call("getByType", { params: { type: "not_a_document" } });

    expect(res.statusCode).toBe(400);
  });
});

describe("GET /legal/pending", () => {
  it("lists what a client has not accepted, and nothing meant only for advocates", async () => {
    const res = await call("listPending", { user: { _id: USER, role: "client" } });

    expect(res.body.data.map((doc) => doc.type)).toEqual(["client_terms"]);
  });

  it("is empty once the active version is accepted", async () => {
    mockAcceptances.push({ user: USER, documentType: "client_terms", version: "1.0" });

    const res = await call("listPending", { user: { _id: USER, role: "client" } });

    expect(res.body.data).toEqual([]);
  });

  it("asks again when a new version is published", async () => {
    mockAcceptances.push({ user: USER, documentType: "client_terms", version: "0.9" });

    const res = await call("listPending", { user: { _id: USER, role: "client" } });

    expect(res.body.data.map((doc) => doc.version)).toEqual(["1.0"]);
  });
});

describe("POST /legal/accept", () => {
  it("records an acceptance of the active version", async () => {
    const res = await call("accept", {
      user: { _id: USER, role: "client" },
      body: { type: "client_terms", version: "1.0" },
    });

    expect(res.statusCode).toBe(201);
    expect(mockAcceptances).toHaveLength(1);
    expect(mockAcceptances[0].version).toBe("1.0");
  });

  it("refuses a version that is no longer published", async () => {
    const res = await call("accept", {
      user: { _id: USER, role: "client" },
      body: { type: "client_terms", version: "0.9" },
    });

    expect(res.statusCode).toBe(409);
    expect(mockAcceptances).toHaveLength(0);
  });

  it("does not duplicate an acceptance", async () => {
    const body = { type: "client_terms", version: "1.0" };
    await call("accept", { user: { _id: USER, role: "client" }, body });
    const res = await call("accept", { user: { _id: USER, role: "client" }, body });

    expect(res.statusCode).toBe(200);
    expect(mockAcceptances).toHaveLength(1);
  });

  it("requires both a type and a version", async () => {
    const res = await call("accept", {
      user: { _id: USER, role: "client" },
      body: { type: "client_terms" },
    });

    expect(res.statusCode).toBe(400);
  });
});
